# frozen_string_literal: true

RailsDiscordNotifier.configure do |config|
  # Required. A Discord (https://discord.com/api/webhooks/...) or Google Chat
  # (https://chat.googleapis.com/v1/spaces/...) webhook URL. The message format
  # follows the URL. If it is missing or malformed the notifier stays disabled and
  # logs a warning rather than breaking boot. Keep it out of source control.
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL", nil).presence || ENV.fetch("GOOGLE_CHAT_WEBHOOK_URL", nil)

  # Appearance of the bot in Discord. Google Chat uses the name and avatar set on
  # the webhook itself.
  config.username = ENV.fetch("ERROR_BOT_NAME", "Error Bot")
  # config.avatar_url = ENV.fetch("ERROR_BOT_AVATAR_URL", nil)

  # Reporting is off in development and test by default.
  # config.enabled = Rails.env.production?

  # Deliver off the request thread. Set to false only if you need delivery to be
  # synchronous (for example inside a test).
  # config.async = true

  # Collapse repeats of the same error for this many seconds. 0 disables it.
  # config.throttle_period = 60

  # Network timeouts, in seconds. Kept short so a slow webhook never slows you down.
  # config.open_timeout  = 2
  # config.read_timeout  = 5
  # config.write_timeout = 5

  # Client-caused noise that is ignored by default. Append your own:
  # config.ignored_exceptions += %w[MyApp::HarmlessError]

  # Request parameters are included, filtered with your app's
  # config.filter_parameters plus the gem's own list. Turn them off entirely with:
  # config.include_params = false
  # config.filter_parameters += %w[national_id]

  # Extra fields on every report. Receives the Rack env (nil outside a request).
  # config.context = lambda do |env|
  #   { "User" => env&.dig("warden")&.user&.id }
  # end

  # Shown as a field, handy for matching an error to a deploy.
  # config.release = ENV.fetch("GIT_COMMIT_SHA", nil)

  # Entry points. Middleware catches web requests; the Rails.error subscriber
  # catches jobs, rake tasks and runners (Rails 7.0+).
  # config.install_middleware = true
  # config.install_error_subscriber = true
end
