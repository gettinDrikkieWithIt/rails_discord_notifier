require "rails/generators"

module RailsDiscordNotifier
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    def copy_initializer
      template "rails_discord_notifier.rb", "config/initializers/rails_discord_notifier.rb"
    end
  end
end
