# frozen_string_literal: true

RailsDiscordNotifier.configure do |config|
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL")
  config.username    = ENV.fetch("ERROR_BOT_NAME", "Error Bot")
  # config.avatar_url = "https://example.com/avatar.png"
end
