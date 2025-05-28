# lib/rails_discord_notifier.rb
# frozen_string_literal: true

require "rails_discord_notifier/version"
require "rails_discord_notifier/middleware"
require "rails_discord_notifier/railtie" if defined?(Rails)

module RailsDiscordNotifier
  class << self
    # webhook_url (String) incoming Discord webhook URL
    attr_accessor :webhook_url, :username, :avatar_url

    # Configure via initializer: RailsDiscordNotifier.configure do |config| ... end
    def configure
      yield self
      raise ArgumentError, "webhook_url is required" unless webhook_url
    end
  end
end
