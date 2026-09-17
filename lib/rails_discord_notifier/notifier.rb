# frozen_string_literal: true

require "monitor"

module RailsDiscordNotifier
  # Decides whether an exception is worth reporting, then hands it to the client.
  #
  # Delivery happens off the request thread by default, and repeats of the same
  # error are collapsed, so an error storm cannot slow the application down or
  # bury the Discord channel.
  class Notifier
    MAX_TRACKED_FINGERPRINTS = 1_000

    # Stamped on an exception once it has been reported, so that the middleware
    # and the Rails.error subscriber cannot both announce the same failure.
    REPORTED_FLAG = :@__rails_discord_notifier_reported

    def initialize(config, client: Client.new(config), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @config = config
      @client = client
      @clock  = clock
      @seen    = {}
      @threads = []
      @lock    = Monitor.new
    end

    # Waits for in-flight asynchronous deliveries. Registered with at_exit the
    # first time one is spawned, because Ruby kills non-main threads when the
    # process exits - which would otherwise silently drop the reports from
    # rake tasks, runners and other short-lived processes.
    def flush(timeout: nil)
      timeout ||= config.open_timeout.to_f + config.read_timeout.to_f + config.write_timeout.to_f
      in_flight = @lock.synchronize { @threads.dup }
      in_flight.each { |thread| thread.join(timeout) }
      @lock.synchronize { @threads.select!(&:alive?) }
      nil
    end

    # Returns the delivery Thread when asynchronous, the client result when
    # synchronous, and false when the exception was not reportable.
    def notify(exception, env: nil, context: {})
      return false unless report?(exception)
      return false if already_reported?(exception)

      mark_reported(exception)
      payload = Payload.new(exception, config: config, env: env, context: context)
      return false if throttled?(payload.fingerprint)

      deliver(payload.to_h)
    rescue StandardError => e
      log_internal_failure(e)
      false
    end

    private

    attr_reader :config, :client, :clock

    def report?(exception)
      config.enabled? && !config.ignore?(exception)
    end

    def already_reported?(exception)
      exception.instance_variable_defined?(REPORTED_FLAG)
    rescue StandardError
      false
    end

    # Frozen exceptions simply go unmarked; at worst they are reported twice.
    def mark_reported(exception)
      exception.instance_variable_set(REPORTED_FLAG, true)
    rescue StandardError
      nil
    end

    def deliver(body)
      return client.post(body) unless config.async

      register_flush_at_exit
      track(Thread.new do
        client.post(body)
      rescue StandardError => e
        log_internal_failure(e)
      end)
    end

    def track(thread)
      @lock.synchronize do
        @threads.select!(&:alive?)
        @threads << thread
      end
      thread
    end

    def register_flush_at_exit
      @lock.synchronize do
        next if @flush_registered

        @flush_registered = true
        at_exit { flush }
      end
    end

    # True when this exact error was already reported inside the throttle window.
    def throttled?(fingerprint)
      period = config.throttle_period.to_f
      return false if period <= 0

      @lock.synchronize do
        now = clock.call
        prune(now, period)
        next true if @seen[fingerprint] && (now - @seen[fingerprint]) < period

        @seen[fingerprint] = now
        false
      end
    end

    def prune(now, period)
      @seen.delete_if { |_, seen_at| (now - seen_at) >= period }
      return if @seen.size <= MAX_TRACKED_FINGERPRINTS

      @seen.shift while @seen.size > MAX_TRACKED_FINGERPRINTS
    end

    def log_internal_failure(error)
      config.logger.error("[RailsDiscordNotifier] notification failed: #{error.class}: #{error.message}")
    end
  end
end
