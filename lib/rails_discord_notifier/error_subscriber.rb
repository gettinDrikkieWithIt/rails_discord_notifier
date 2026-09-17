# frozen_string_literal: true

module RailsDiscordNotifier
  # Subscriber for ActiveSupport::ErrorReporter (Rails 7.0+).
  #
  # This is what catches failures the Rack middleware never sees: background
  # jobs, rake tasks, runners and anything wrapped in Rails.error.handle/record.
  class ErrorSubscriber
    def initialize(notifier: nil)
      @notifier = notifier
    end

    # `source:` only exists from Rails 7.1 onwards, hence the default.
    def report(error, handled:, severity:, context: {}, source: nil)
      context = context.to_h
      notifier.notify(
        error,
        env: context[:env] || context["env"],
        context: extra_fields(handled, severity, source, context)
      )
    rescue StandardError
      # A failing reporter must not break the code that reported the error.
      nil
    end

    private

    def extra_fields(handled, severity, source, context)
      fields = { "Severity" => severity.to_s, "Handled" => handled.to_s }
      fields["Source"] = source.to_s if source
      context.except(:env, "env").each { |key, value| fields[key.to_s] = value.to_s }
      fields
    end

    def notifier
      @notifier || RailsDiscordNotifier.notifier
    end
  end
end
