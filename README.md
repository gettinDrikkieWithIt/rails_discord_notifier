# RailsDiscordNotifier

**Send Rails exceptions to Discord via an incoming webhook**

RailsDiscordNotifier is a lightweight gem that captures unhandled exceptions in your Rails application and delivers detailed error reports directly to a Discord channel via a configurable webhook. You own the codebase and can customize the format, embed fields, and delivery settings to suit your needs.

## Features

- Middleware-based interception of all uncaught exceptions
- Rich embed messages with exception class, message, backtrace, request method \& URL, and timestamp
- Configurable bot username and avatar
- Safe error handling: failures in notification do not interrupt your app
- Simple install and setup via Rails initializer or direct middleware inclusion

## Installation

Add the gem directly from RubyGems.org by including it in your Gemfile:

```ruby
gem "rails_discord_notifier", "~> #{RailsDiscordNotifier::VERSION}"
```

Then install:

```bash
bundle install
```

Alternatively, you can add it with Bundler:

```bash
bundle add rails_discord_notifier
```

## Usage

Generate the default initializer in your Rails app:

```bash
rails generate rails_discord_notifier:install
```

Fill in your Discord incoming webhook URL and optional settings in `config/initializers/rails_discord_notifier.rb`:

```ruby
RailsDiscordNotifier.configure do |config|
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL")
  config.username    = ENV.fetch("ERROR_BOT_NAME", "Error Bot")
  # config.avatar_url = "https://example.com/avatar.png"
end
```

Ensure middleware is loaded (it’s added automatically by the Railtie).

Any unhandled exception in your controllers or middleware stack will now post an embed to Discord before re-raising.

## Configuration Options

| Option       | Type   | Default        | Description                             |
|--------------|--------|----------------|-----------------------------------------|
| `webhook_url`| String | **Required**   | Discord incoming webhook URL            |
| `username`   | String | `"Error Bot"` | Bot display name                        |
| `avatar_url` | String | `nil`          | URL of the bot avatar image             |

## Development

1. Checkout the repo
2. Run `bin/setup` to install dependencies
3. Run `bundle exec rspec` to execute the test suite
4. Build and install locally:
   ```bash
   gem build rails_discord_notifier.gemspec
   gem install ./rails_discord_notifier-#{RailsDiscordNotifier::VERSION}.gem
   ```
5. To release (public gems) update `version.rb` and run:
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
