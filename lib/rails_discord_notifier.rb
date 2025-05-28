require "rails_discord_notifier/version"
require "rails_discord_notifier/railtie" if defined?(Rails)

module RailsDiscordNotifier
  class << self
    attr_accessor :webhook_url, :username, :avatar_url

    # User calls this in an initializer
    def configure
      yield self
      raise ArgumentError, "webhook_url is required" unless webhook_url
    end
  end
end
