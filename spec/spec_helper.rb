# frozen_string_literal: true

require "bundler/setup"
require "logger"
require "stringio"
require "rack"
require "webmock/rspec"

require_relative "support/dummy_app"
require_relative "support/exception_helpers"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!

  config.before do
    DummyApp.reset!
    RailsDiscordNotifier.reset!
    RailsDiscordNotifier.config.webhook_url = "https://discord.com/api/webhooks/1/token"
    RailsDiscordNotifier.config.enabled = true
    RailsDiscordNotifier.config.async = false
    RailsDiscordNotifier.config.throttle_period = 0
  end
end
