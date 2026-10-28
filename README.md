# RailsDiscordNotifier

Send Rails exceptions to a Discord channel or a Google Chat space via an
incoming webhook.

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
gem "rails_discord_notifier", "~> 0.3"
```

```bash
bundle install
rails generate rails_discord_notifier:install
```

Then set your webhook. The gem works out which service it is from the URL.

**Discord:** Server Settings → Integrations → Webhooks → Copy URL.

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/…/…"
```

**Google Chat:** open the space → Apps & integrations → Webhooks → Add webhook,
then copy the URL. Your Workspace admin must allow incoming webhooks.

```bash
export GOOGLE_CHAT_WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/…/messages?key=…&token=…"
```

The generated initializer reads `DISCORD_WEBHOOK_URL`, then
`GOOGLE_CHAT_WEBHOOK_URL`. Treat either URL as a password: anyone holding it
can post to your channel.

## Verify it works

```bash
bundle exec rails_discord_notifier test
```

This posts a real sample report to your webhook and prints what the service
said, so you find out now rather than during your next incident. It reads
`DISCORD_WEBHOOK_URL`, then `GOOGLE_CHAT_WEBHOOK_URL`, or takes `--webhook URL`
(which ends up in your shell history, so prefer the environment variable).

## What a report looks like

In Discord, an embed titled with the failing request, followed by the details
you need to find the error:

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

In Google Chat, the same details as a single text message, with the params and
backtrace in code blocks. Chat has no per-message sender name or avatar: those
come from the name and avatar you gave the webhook when you created it.

The backtrace goes through `Rails.backtrace_cleaner`, as on Rails' own error
pages, so it shows your app's frames rather than gem internals. When an error
never reaches your code, such as a job class that doesn't exist, the library
frames are shown with short gem paths instead. On Heroku, `Host` is the dyno
name (`web.1`, `worker.2`) rather than the dyno's random hostname.

## Configuration

Everything is optional except `webhook_url`.

| Option | Default | Description |
|---|---|---|
| `webhook_url` | `nil` | **Required.** Must be `https://` on `discord.com`, `discordapp.com` or `chat.googleapis.com`. Anything else leaves the notifier disabled. |
| `enabled` | `false` in development and test, `true` elsewhere | Master switch. |
| `username` | `"Error Bot"` | Bot display name. Discord only. |
| `avatar_url` | `nil` | Bot avatar image. Discord only. |
| `async` | `true` | Deliver on a separate thread so a failing request is not slowed down. |
| `throttle_period` | `60` | Seconds to collapse repeats of the same error. `0` disables. |
| `ignored_exceptions` | routing/404-style noise (see below) | Exception class names, matched including subclasses. |
| `include_params` | `true` | Include filtered request parameters. |
| `filter_parameters` | `[]` | Extra redaction matchers, unioned with your app's `config.filter_parameters` and the gem's built-in list. |
| `backtrace_lines` | `10` | Backtrace lines to send after cleaning, trimmed to fit the message size limit. |
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
`config.include_params = false`. The same filter applies to extra fields from
`config.context` and from `Rails.error` context.

Exception messages are free text rather than structured parameters, so they get
a best-effort scrub instead: `token=abc`, `password="x"`, `Api_Key: abc`,
`"password":"x"`, `Authorization: Bearer abc` and `redis://:password@host` style
fragments are replaced with `[FILTERED]`. This catches the usual culprits (a
database connection error carrying a password, an HTTP error carrying a URL with
a token) but cannot be exhaustive the way parameter filtering is.

Path segments are sent as they are. If a route puts a secret in the path (for
example `/password_resets/:token`), move it to the query string or the body,
where it is filtered.

Request bodies, headers and cookies are never sent.

In Google Chat, text like `<users/all>` or `<https://…|click here>` would become
an @all mention or a disguised link. Since anyone who can make your app raise
controls part of the report (the path, the User-Agent, often the exception
message), the gem defuses these with an invisible zero-width space after each
`<`. The report looks the same but can't ping the space or hide a link. The
space is still there if you copy text out of the report (for example
``in `<main>'`` from a backtrace), so retype the `<` if a search comes up empty.

## Google Chat rate limits

Google Chat accepts about one message per second per space, shared with
anything else posting there. Repeats of the same error are already collapsed
(`throttle_period`), but a burst of *different* errors beyond that rate is
rejected by Google with HTTP 429. Those rejections are logged, not retried.

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

"The same error" means the same exception class, raised from the same line, on
the same controller action. So `/orders/1` and `/orders/2` failing the same way
count as one error for `throttle_period`. At most 10 reports are delivered at
once; during a storm, anything beyond that is dropped with a log line rather
than starting more threads.

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
