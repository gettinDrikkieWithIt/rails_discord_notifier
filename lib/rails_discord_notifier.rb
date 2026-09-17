# frozen_string_literal: true

require "rails_discord_notifier/version"
require "rails_discord_notifier/configuration"
require "rails_discord_notifier/secret_scrubber"
require "rails_discord_notifier/payload"
require "rails_discord_notifier/client"
require "rails_discord_notifier/notifier"
require "rails_discord_notifier/middleware"
require "rails_discord_notifier/error_subscriber"
require "rails_discord_notifier/cli"
require "rails_discord_notifier/railtie" if defined?(Rails::Railtie)

module RailsDiscordNotifier
  class << self
    def config
      @config ||= Configuration.new
    end

    # Configure via initializer:
    #   RailsDiscordNotifier.configure { |config| config.webhook_url = ... }
    #
    # Never raises: a missing or malformed webhook URL leaves the notifier
    # disabled and logs a warning rather than taking down application boot.
    def configure
      yield config
      warn_unless_usable
      config
    end

    def reset!
      @config   = Configuration.new
      @notifier = nil
    end

    def notifier
      @notifier ||= Notifier.new(config)
    end

    # Report an exception by hand, from anywhere (jobs, rake tasks, rescue blocks).
    def notify(exception, env: nil, context: {})
      notifier.notify(exception, env: env, context: context)
    end

    # Backwards-compatible accessors for the pre-0.2 flat configuration API.
    %i[webhook_url username avatar_url].each do |setting|
      define_method(setting) { config.public_send(setting) }
      define_method("#{setting}=") { |value| config.public_send("#{setting}=", value) }
    end

    # ActiveSupport::ErrorReporter, when this Rails version has one (7.0+).
    def error_reporter
      return nil unless defined?(Rails) && Rails.respond_to?(:error)

      reporter = Rails.error
      reporter.respond_to?(:subscribe) ? reporter : nil
    rescue StandardError
      nil
    end

    private

    # Silent when the notifier is off by design (development, test), so the
    # warning only appears where a broken webhook actually costs you reports.
    def warn_unless_usable
      return if !config.enabled || config.valid_webhook_url?

      config.logger.warn(
        "[RailsDiscordNotifier] disabled: webhook_url must be an https://discord.com/api/webhooks/... URL"
      )
    end
  end
end
