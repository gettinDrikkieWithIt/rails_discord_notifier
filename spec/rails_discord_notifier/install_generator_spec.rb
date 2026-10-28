# frozen_string_literal: true

require "generators/rails_discord_notifier/install_generator"

RSpec.describe RailsDiscordNotifier::InstallGenerator do
  # The initializer the generator copies into the host app, evaluated as-is.
  let(:template) do
    File.expand_path("../../lib/generators/rails_discord_notifier/templates/rails_discord_notifier.rb", __dir__)
  end
  let(:google_chat_url) { "https://chat.googleapis.com/v1/spaces/AAA/messages?key=k&token=t" }

  before do
    RailsDiscordNotifier.reset!
    stub_const("ENV", ENV.to_h.except("DISCORD_WEBHOOK_URL").merge(env))
    load template
  end

  context "when only GOOGLE_CHAT_WEBHOOK_URL is set" do
    let(:env) { { "GOOGLE_CHAT_WEBHOOK_URL" => google_chat_url } }

    it { expect(RailsDiscordNotifier.config.webhook_url).to eq(google_chat_url) }
  end

  # Kamal, Docker and .env templates often export unused variables as "".
  context "when DISCORD_WEBHOOK_URL is empty and GOOGLE_CHAT_WEBHOOK_URL is set" do
    let(:env) { { "DISCORD_WEBHOOK_URL" => "", "GOOGLE_CHAT_WEBHOOK_URL" => google_chat_url } }

    it { expect(RailsDiscordNotifier.config.webhook_url).to eq(google_chat_url) }
  end

  context "when DISCORD_WEBHOOK_URL is set" do
    let(:env) { { "DISCORD_WEBHOOK_URL" => "https://discord.com/api/webhooks/1/token" } }

    it { expect(RailsDiscordNotifier.config.webhook_url).to eq("https://discord.com/api/webhooks/1/token") }
  end
end
