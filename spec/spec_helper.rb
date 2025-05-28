# spec/spec_helper.rb
require "bundler/setup"
require "rails_discord_notifier"
require "logger"

# Minimal Rails stub so middleware can call Rails.logger
module Rails
  def self.logger
    @logger ||= Logger.new(StringIO.new)  # or STDOUT if you prefer
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
