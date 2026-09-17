# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-09-17

This release fixes three defects that could leak credentials or silently drop
error reports. Upgrading is strongly recommended.

### Security

- **Nested parameters are now redacted.** Filtering previously only inspected
  top-level keys, so `user[password]` was posted to Discord in cleartext.
  Filtering is now recursive via `ActiveSupport::ParameterFilter` and always
  applies a superset of the host application's `config.filter_parameters`.
- **Query strings are now redacted.** The `URL` field used the raw request URL,
  so a secret in the query string (`?api_key=...`) was posted verbatim.
- **Exception messages are scrubbed.** `token=…`, `password="…"` and
  `Api_Key: …` fragments in an exception or `cause` message are replaced with
  `[FILTERED]`, so a database connection error no longer posts its password.
  Best effort only - a message is free text, unlike structured parameters.
- **Webhook URLs are validated.** Only `https://` URLs on `discord.com` or
  `discordapp.com` (or their subdomains) are accepted, which prevents a
  misconfigured or hostile URL from receiving exception reports.

### Fixed

- **Reports are no longer silently dropped.** Payloads are truncated to
  Discord's documented limits (1024 per field, 256 title, 4096 description,
  6000 per embed). Oversized messages previously returned HTTP 400 and were
  discarded, losing the error being reported.
- **Delivery failures are now visible.** The HTTP response was previously
  discarded; non-2xx responses are logged, and 429s are logged with `Retry-After`.
- **Network timeouts are set** (2s open, 5s read, 5s write). Delivery previously
  had no timeout at all and could hang a request thread indefinitely.
- `Rails.logger` is no longer assumed to exist; the logger is configurable and
  falls back to `$stderr`.
- `require "time"` and `require "rack"` are now explicit, rather than relying on
  another gem having loaded them.
- `rails_discord_notifier/middleware` can be required on its own.

### Added

- **Background jobs, rake tasks and runners are now covered** via an
  `ActiveSupport::ErrorReporter` subscriber (Rails 7.0+). Previously only
  exceptions raised inside a web request were reported.
- **Asynchronous delivery** (`config.async`, on by default), so reporting no
  longer adds a blocking HTTP round-trip to a failing request. In-flight
  deliveries are waited for at process exit, so reports from rake tasks and
  runners are not lost when the process ends (`Notifier#flush`).
- **Throttling** (`config.throttle_period`, 60s by default) collapses repeats of
  the same error, so an error storm cannot flood the channel or trip Discord's
  rate limit. The same exception object is never reported twice.
- **An ignore list** (`config.ignored_exceptions`) pre-populated with routing,
  `RecordNotFound` and other client-caused noise.
- **`config.enabled`**, defaulting to off in development and test.
- **`rails_discord_notifier test`** posts a sample report to your webhook and
  prints Discord's response. The executable previously did nothing.
- **Richer reports**: request ID, environment, release, hostname, the exception's
  `cause`, and arbitrary extra fields via `config.context`.
- `RailsDiscordNotifier.notify` for reporting an exception by hand.
- `config.include_params`, `config.filter_parameters`, `config.backtrace_lines`,
  `config.install_middleware`, `config.install_error_subscriber`.
- RBS signatures for the public API.

### Changed

- **`configure` no longer raises** when `webhook_url` is missing. A missing
  environment variable logs a warning and leaves the notifier disabled instead
  of taking down application boot.
- Configuration moved to a `Configuration` object. The previous flat accessors
  (`RailsDiscordNotifier.webhook_url = ...`) still work.
- Depends on `actionpack`, `activesupport`, `railties`, `rack` and `logger`
  rather than the whole `rails` meta-gem. Minimum Rails is now 6.1.
- The timestamp uses Discord's native embed `timestamp` instead of a field.
- Backtraces default to 10 lines (was 5), trimmed to fit Discord's field limit.

## [0.1.2] - 2025-06-10

- Add `frozen_string_literal` comments throughout
- Require MFA for RubyGems pushes
- Move development dependencies out of the gemspec and into the Gemfile

## [0.1.1] - 2025-06-03

- Fix security and stability issues in the middleware

## [0.1.0] - 2025-05-28

- Initial release
