# frozen_string_literal: true

require "rails/railtie"

module RailsDiscordNotifier
  class Railtie < Rails::Railtie
    # Both hooks run after config/initializers so that anything the host app
    # sets in its initializer is already in place when we read it.

    initializer "rails_discord_notifier.middleware", after: :load_config_initializers do |app|
      app.middleware.use(RailsDiscordNotifier::Middleware) if RailsDiscordNotifier.config.install_middleware
    end

    initializer "rails_discord_notifier.error_subscriber", after: :load_config_initializers do
      if RailsDiscordNotifier.config.install_error_subscriber && RailsDiscordNotifier.error_reporter
        RailsDiscordNotifier.error_reporter.subscribe(RailsDiscordNotifier::ErrorSubscriber.new)
      end
    end
  end
end
