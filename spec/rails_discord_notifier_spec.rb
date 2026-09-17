# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier do
  describe "VERSION" do
    it { expect(described_class::VERSION).not_to be_nil }
  end

  describe ".config" do
    it { expect(described_class.config).to be_a(RailsDiscordNotifier::Configuration) }
    it { expect(described_class.config).to equal(described_class.config) }
  end

  describe ".configure" do
    it "yields the configuration" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.config)
    end

    it "applies the configured values" do
      described_class.configure { |c| c.username = "Sentry Bot" }
      expect(described_class.config.username).to eq("Sentry Bot")
    end

    it { expect(described_class.configure { |c| c.username = "x" }).to be_a(RailsDiscordNotifier::Configuration) }
  end

  describe ".configure without a webhook url" do
    before do
      described_class.reset!
      allow(described_class.config.logger).to receive(:warn)
      described_class.configure { |c| c.enabled = true }
    end

    it { expect { described_class.configure { |c| c.webhook_url = nil } }.not_to raise_error }
    it { expect(described_class.config.logger).to have_received(:warn).with(/webhook_url/) }
    it { expect(described_class.config).not_to be_enabled }
  end

  describe ".configure when reporting is deliberately disabled" do
    before do
      described_class.reset!
      allow(described_class.config.logger).to receive(:warn)
      described_class.configure { |c| c.enabled = false }
    end

    it { expect(described_class.config.logger).not_to have_received(:warn) }
  end

  describe ".configure with a non-Discord webhook url" do
    before do
      allow(described_class.config.logger).to receive(:warn)
      described_class.config.enabled = true
      described_class.configure { |c| c.webhook_url = "https://evil.example.com/hook" }
    end

    it { expect(described_class.config.logger).to have_received(:warn).with(/webhook_url/) }
  end

  describe "the pre-0.2 flat accessors" do
    before { described_class.webhook_url = "https://discord.com/api/webhooks/9/tok" }

    it { expect(described_class.webhook_url).to eq("https://discord.com/api/webhooks/9/tok") }
    it { expect(described_class.config.webhook_url).to eq("https://discord.com/api/webhooks/9/tok") }

    it "exposes username" do
      described_class.username = "Legacy Bot"
      expect(described_class.config.username).to eq("Legacy Bot")
    end

    it "exposes avatar_url" do
      described_class.avatar_url = "https://example.com/a.png"
      expect(described_class.config.avatar_url).to eq("https://example.com/a.png")
    end
  end

  describe ".notify" do
    let(:exception) { captured_exception }

    before do
      allow(described_class.notifier).to receive(:notify)
      described_class.notify(exception, context: { "Job" => "ImportJob" })
    end

    it { expect(described_class.notifier).to have_received(:notify).with(exception, any_args) }
  end

  describe ".reset!" do
    before do
      described_class.config.username = "Changed"
      described_class.reset!
    end

    it { expect(described_class.config.username).to eq("Error Bot") }
  end
end
