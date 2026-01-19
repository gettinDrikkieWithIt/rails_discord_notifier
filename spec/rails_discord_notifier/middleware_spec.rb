# frozen_string_literal: true

require "rails_discord_notifier/middleware"

RSpec.describe RailsDiscordNotifier::Middleware do
  let(:app) { ->(_env) { raise "boom!" } }
  let(:middleware) { described_class.new(app) }

  before do
    RailsDiscordNotifier.webhook_url = "https://discord.com/api/webhooks/test"
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(true)
  end

  it "forwards exceptions after notifying Discord" do
    expect { middleware.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/") }.to raise_error(RuntimeError, "boom!")
  end
end
