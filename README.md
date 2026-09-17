# RailsDiscordNotifier

Send Rails exceptions to a Discord channel via an incoming webhook.

- Catches unhandled exceptions from **web requests** (Rack middleware) and from
  **background jobs, rake tasks and runners** (`Rails.error` subscriber, Rails 7.0+)
- **Redacts secrets** from params and query strings, using your app's own
  `config.filter_parameters` plus a built-in list
- **Never slows down or breaks your app**: delivery happens off the request
  thread, with short timeouts, and every failure is logged rather than raised
- **Never floods your channel**: repeats of the same error are collapsed, and
  routing/404-style noise is ignored by default

## Installation

```ruby
gem "rails_discord_notifier", "~> 0.2"
```

```bash
bundle install
rails generate rails_discord_notifier:install
```

Then set your webhook (Server Settings → Integrations → Webhooks → Copy URL):

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/…/…"
```

## Verify it works

```bash
bundle exec rails_discord_notifier test
```

This posts a real sample report to your webhook and prints what Discord said,
so you find out now rather than during your next incident.

## What a report looks like

An embed titled with the failing request, followed by the details you need to
find the error:

```
Exception in POST /orders
ActiveRecord::RecordInvalid: Validation failed: Email can't be blank
Caused by ArgumentError: missing email

URL          https://shop.example.com/orders?utm_source=newsletter
Controller   orders          Action   create
Environment  production      Release  a1b2c3d
Request ID   8f3c…           Host     web-01
Params       { "order": { "email": "", "card_token": "[FILTERED]" } }
Backtrace    `app/controllers/orders_controller.rb:42:in 'create'` …
```

## Configuration

Everything is optional except `webhook_url`.

| Option | Default | Description |
|---|---|---|
| `webhook_url` | `nil` | **Required.** Must be `https://` on `discord.com` or `discordapp.com`. Anything else leaves the notifier disabled. |
| `enabled` | `false` in development and test, `true` elsewhere | Master switch. |
| `username` | `"Error Bot"` | Bot display name in Discord. |
| `avatar_url` | `nil` | Bot avatar image. |
| `async` | `true` | Deliver on a separate thread so a failing request is not slowed down. |
| `throttle_period` | `60` | Seconds to collapse repeats of the same error. `0` disables. |
| `ignored_exceptions` | routing/404-style noise (see below) | Exception class names, matched including subclasses. |
| `include_params` | `true` | Include filtered request parameters. |
| `filter_parameters` | `[]` | Extra redaction matchers, unioned with your app's `config.filter_parameters` and the gem's built-in list. |
| `backtrace_lines` | `10` | Backtrace lines to send, trimmed to fit Discord's field limit. |
| `open_timeout` / `read_timeout` / `write_timeout` | `2` / `5` / `5` | Seconds. |
| `environment` | `Rails.env`, else `RAILS_ENV`/`RACK_ENV` | Shown as a field, and decides the `enabled` default. |
| `release` | `nil` | Shown as a field; handy for matching an error to a deploy. |
| `context` | `nil` | Callable receiving the Rack env (`nil` outside a request), returning a hash of extra fields. |
| `logger` | `Rails.logger`, else `$stderr` | Where delivery problems are logged. |
| `install_middleware` | `true` | Install the Rack middleware. |
| `install_error_subscriber` | `true` | Subscribe to `Rails.error` (Rails 7.0+). |

```ruby
RailsDiscordNotifier.configure do |config|
  config.webhook_url = ENV.fetch("DISCORD_WEBHOOK_URL", nil)
  config.release     = ENV.fetch("GIT_COMMIT_SHA", nil)

  config.ignored_exceptions += %w[MyApp::HarmlessError]

  config.context = ->(env) { { "User" => env&.dig("warden")&.user&.id } }
end
```

A missing or malformed `webhook_url` logs a warning and disables the notifier.
It will never take down application boot.

### Ignored by default

`ActionController::RoutingError`, `ActiveRecord::RecordNotFound`,
`ActionController::InvalidAuthenticityToken`, `ActionController::UnknownFormat`,
`ActionController::BadRequest`, `Rack::QueryParser::ParameterTypeError` and
similar client-caused errors. See `Configuration::DEFAULT_IGNORED_EXCEPTIONS`
for the full list. Replace it wholesale with `config.ignored_exceptions = [...]`
or extend it with `+=`.

## Secret redaction

Parameters and query strings are filtered recursively with
`ActiveSupport::ParameterFilter`, using the union of:

1. your application's `config.filter_parameters`,
2. anything you add via `config.filter_parameters`, and
3. the gem's built-in list (`passw`, `secret`, `token`, `_key`, `crypt`, `salt`,
   `certificate`, `otp`, `ssn`, `signature`, `authorization`, `cookie`,
   `session`, `credential`).

Because it is a union, enabling this gem can never redact less than your
application already does. To send no parameters at all, set
`config.include_params = false`.

Exception messages are free text rather than structured parameters, so they get
a best-effort scrub instead: `token=abc`, `password="x"` and `Api_Key: abc` style
fragments are replaced with `[FILTERED]`. This catches the usual culprits (a
database connection error carrying a password, an HTTP error carrying a URL with
a token) but cannot be exhaustive the way parameter filtering is.

Request bodies, headers and cookies are never sent.

## Reporting an exception yourself

```ruby
rescue SomeError => e
  RailsDiscordNotifier.notify(e, context: { "Tenant" => tenant.id })
end
```

## How it gets your exceptions

| Source | Mechanism | Requires |
|---|---|---|
| Controllers, routing, Rack apps | `RailsDiscordNotifier::Middleware` | any supported Rails |
| Active Job, rake tasks, runners, `Rails.error.handle/record` | `RailsDiscordNotifier::ErrorSubscriber` | Rails 7.0+ |
| Anything else | `RailsDiscordNotifier.notify` | — |

The middleware observes and re-raises, so it never changes how your application
handles errors. When both entry points see the same exception, it is reported once.

Asynchronous deliveries still in flight are waited for at process exit, so a
report from a rake task or `rails runner` is not lost when the process ends. Call
`RailsDiscordNotifier.notifier.flush` to wait for them explicitly.

## Compatibility

Ruby 3.1+, Rails 6.1+. Every supported combination is exercised in CI.

## Development

```bash
bin/setup                 # install dependencies
bundle exec rspec         # run the test suite
bundle exec rubocop       # lint
bundle exec appraisal install && bundle exec appraisal rspec   # all Rails versions
```

To release: update `lib/rails_discord_notifier/version.rb` and `CHANGELOG.md`,
then `bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome at
<https://github.com/gettinDrikkieWithIt/rails_discord_notifier>.
Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

MIT. See [LICENSE.txt](LICENSE.txt).
