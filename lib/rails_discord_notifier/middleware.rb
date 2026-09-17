# frozen_string_literal: true

module RailsDiscordNotifier
  # Rack middleware that reports unhandled exceptions and then gets out of the way.
  #
  # The exception is always re-raised: this middleware observes, it never handles.
  class Middleware
    def initialize(app, notifier: nil)
      @app      = app
      @notifier = notifier
    end

    def call(env)
      @app.call(env)
    rescue StandardError => e
      notify(e, env)
      raise
    end

    private

    def notify(exception, env)
      notifier.notify(exception, env: env)
    rescue StandardError
      # Reporting must never mask the original exception.
      nil
    end

    def notifier
      @notifier || RailsDiscordNotifier.notifier
    end
  end
end
