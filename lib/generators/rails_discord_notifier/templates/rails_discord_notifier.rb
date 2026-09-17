# frozen_string_literal: true

RailsDiscordNotifier.configure do |config|
  # Required. Must be an https://discord.com/api/webhooks/... URL.
  # If it is missing or malformed the notifier stays disabled and logs a warning
  # rather than breaking boot.
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL", nil)

  # Appearance of the bot in Discord.
  config.username = ENV.fetch("ERROR_BOT_NAME", "Error Bot")
  # config.avatar_url = ENV.fetch("ERROR_BOT_AVATAR_URL", nil)

  # Reporting is off in development and test by default.
  # config.enabled = Rails.env.production?

  # Deliver off the request thread. Set to false only if you need delivery to be
  # synchronous (for example inside a test).
  # config.async = true

  # Collapse repeats of the same error for this many seconds. 0 disables it.
  # config.throttle_period = 60

  # Network timeouts, in seconds. Kept short so a slow Discord never slows you down.
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
