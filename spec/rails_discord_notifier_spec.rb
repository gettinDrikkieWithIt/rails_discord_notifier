# spec/rails_discord_notifier_spec.rb
require "spec_helper"

RSpec.describe RailsDiscordNotifier do
  it "has a version number" do
    expect(RailsDiscordNotifier::VERSION).not_to be_nil
  end

  describe ".configure" do
    after { RailsDiscordNotifier.webhook_url = nil }

    it "yields the config object" do
      called = false
      RailsDiscordNotifier.configure do |config|
        called = true
        config.webhook_url = "https://discord.test/webhook"
      end
      expect(called).to be true
      expect(RailsDiscordNotifier.webhook_url).to eq("https://discord.test/webhook")
    end

    it "raises if webhook_url is not set" do
      expect {
        RailsDiscordNotifier.configure { |c| }
      }.to raise_error(ArgumentError, /webhook_url is required/)
    end
  end
end
