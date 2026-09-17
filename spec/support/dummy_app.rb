# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require "rails"
require "action_controller/railtie"

# Loaded before the application is defined so the gem's Railtie is registered
# and genuinely exercised during boot.
require "rails_discord_notifier"

module Dummy
  class Application < Rails::Application
    config.eager_load           = false
    config.logger               = Logger.new(StringIO.new)
    config.secret_key_base      = "dummy" * 10
    config.root                 = File.expand_path("../../tmp/dummy", __dir__)
    config.filter_parameters   += %i[passw secret token _key]
  end
end

Rails.application.initialize!

module DummyApp
  DEFAULT_FILTER_PARAMETERS = Rails.application.config.filter_parameters.dup.freeze

  # Restores the bits of global Rails state individual examples are allowed to change.
  def self.reset!
    Rails.logger = Logger.new(StringIO.new)
    Rails.env = "test"
    Rails.application.config.filter_parameters = DEFAULT_FILTER_PARAMETERS.dup
  end
end
