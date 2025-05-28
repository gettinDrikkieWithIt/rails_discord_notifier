RailsDiscordNotifier.configure do |config|
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL")
  config.username    = "MyApp Error Bot"
  # config.avatar_url = "https://example.com/avatar.png"
end
