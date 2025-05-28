require "rails"
module RailsDiscordNotifier
  class Railtie < Rails::Railtie
    config.before_initialize do
      # allow default values
      RailsDiscordNotifier.username   ||= "Error Bot"
      RailsDiscordNotifier.avatar_url ||= nil
    end

    initializer "rails_discord_notifier.insert_middleware" do |app|
      app.middleware.use RailsDiscordNotifier::Middleware
    end
  end
end
