# RailsDiscordNotifier

**Send Rails exceptions to Discord via an incoming webhook**

RailsDiscordNotifier is a lightweight gem that captures unhandled exceptions in your Rails application and delivers detailed error reports directly to a Discord channel via a configurable webhook. You own the codebase and can customize the format, embed fields, and delivery settings to suit your needs.

## Features

- Middleware-based interception of all uncaught exceptions
- Rich embed messages with exception class, message, backtrace, request method & URL, and timestamp
- Configurable via environment variables and initializer
- Safe error handling: notification failures are logged but don’t interrupt your app

## Installation

Add the gem directly from RubyGems.org by including it in your Gemfile:

```ruby
gem "rails_discord_notifier", "~> 0.1.0"
```

Then install:

```bash
bundle install
```

Or use Bundler:

```bash
bundle add rails_discord_notifier
```

## Usage

Generate the default initializer in your Rails app:

```bash
rails generate rails_discord_notifier:install
```

In `config/initializers/rails_discord_notifier.rb`, configure your webhook and options:

```ruby
RailsDiscordNotifier.configure do |config|
  # Discord webhook URL (required)
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL")

  # Bot username (optional, defaults to ENV["ERROR_BOT_NAME"] or "Error Bot")
  config.username    = ENV.fetch("ERROR_BOT_NAME", "Error Bot")

  # Bot avatar URL (optional)
  # config.avatar_url = ENV.fetch("ERROR_BOT_AVATAR_URL", nil)
end
```

Ensure the middleware is loaded (added automatically by the Railtie).

Any uncaught exception in your controllers or middleware stack will now send an embed to Discord before re-raising.

## Configuration Options

| Option        | Type   | Default                              | Description                        |
|---------------|--------|--------------------------------------|------------------------------------|
| `webhook_url` | String | **Required**                         | Discord incoming webhook URL       |
| `username`    | String | fetched from ENV `ERROR_BOT_NAME` (defaults to `"Error Bot"`) | Bot display name                   |
| `avatar_url`  | String | fetched from ENV `ERROR_BOT_AVATAR_URL` (defaults to `nil`)  | URL of the bot avatar image        |

## Development

1. Checkout the repo
2. Run `bin/setup` to install dependencies
3. Run `bundle exec rspec` to execute the test suite
4. Build and install locally:
   ```bash
   gem build rails_discord_notifier.gemspec
   gem install ./rails_discord_notifier-#{RailsDiscordNotifier::VERSION}.gem
   ```
5. To release (public gem) update `lib/rails_discord_notifier/version.rb` and run:
   ```bash
   bundle exec rake release
   ```

## Contributing

Bug reports and pull requests are welcome on GitHub:
[https://github.com/gettinDrikkieWithIt/rails_discord_notifier](https://github.com/gettinDrikkieWithIt/rails_discord_notifier)

Please follow the project’s Code of Conduct.

## License

This gem is available as open source under the terms of the MIT License.  
See [LICENSE.txt](LICENSE.txt) for details.
