# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::Configuration do
  subject(:config) { described_class.new }

  describe "#username" do
    it { expect(config.username).to eq("Error Bot") }
  end

  describe "#avatar_url" do
    it { expect(config.avatar_url).to be_nil }
  end

  describe "#async" do
    it { expect(config.async).to be true }
  end

  describe "#open_timeout" do
    it { expect(config.open_timeout).to eq(2) }
  end

  describe "#read_timeout" do
    it { expect(config.read_timeout).to eq(5) }
  end

  describe "#write_timeout" do
    it { expect(config.write_timeout).to eq(5) }
  end

  describe "#throttle_period" do
    it { expect(config.throttle_period).to eq(60) }
  end

  describe "#include_params" do
    it { expect(config.include_params).to be true }
  end

  describe "#install_middleware" do
    it { expect(config.install_middleware).to be true }
  end

  describe "#install_error_subscriber" do
    it { expect(config.install_error_subscriber).to be true }
  end

  describe "#backtrace_lines" do
    it { expect(config.backtrace_lines).to eq(10) }
  end

  describe "#filter_parameters" do
    it { expect(config.filter_parameters).to include("passw") }

    context "when the host app defines its own" do
      before { Rails.application.config.filter_parameters = [:note] }

      it { expect(config.filter_parameters).to include(:note) }
      it { expect(config.filter_parameters).to include("passw") }
    end

    context "when Rails has no application" do
      before { Rails.application = nil }

      it { expect(config.filter_parameters).to include("passw") }
    end
  end

  describe "#ignored_exceptions" do
    it { expect(config.ignored_exceptions).to include("ActionController::RoutingError") }
  end

  describe "#environment" do
    it { expect(config.environment).to eq("test") }
  end

  describe "#enabled" do
    context "when Rails.env is test" do
      it { expect(config.enabled).to be false }
    end

    context "when Rails.env is development" do
      before { Rails.env = "development" }

      it { expect(config.enabled).to be false }
    end

    context "when Rails.env is production" do
      before { Rails.env = "production" }

      it { expect(config.enabled).to be true }
    end
  end

  describe "#environment=" do
    before { config.environment = "production" }

    it { expect(config.environment).to eq("production") }
    it { expect(config.enabled).to be true }

    context "when enabled was set explicitly" do
      before { config.enabled = false }

      it { expect(config.enabled).to be false }
    end
  end

  describe "#enabled?" do
    before do
      config.enabled = true
      config.webhook_url = "https://discord.com/api/webhooks/1/token"
    end

    it { expect(config).to be_enabled }

    context "when enabled is false" do
      before { config.enabled = false }

      it { expect(config).not_to be_enabled }
    end

    context "when webhook_url is missing" do
      before { config.webhook_url = nil }

      it { expect(config).not_to be_enabled }
    end

    context "when webhook_url is blank" do
      before { config.webhook_url = "  " }

      it { expect(config).not_to be_enabled }
    end

    context "when webhook_url is not https" do
      before { config.webhook_url = "http://discord.com/api/webhooks/1/token" }

      it { expect(config).not_to be_enabled }
    end

    context "when webhook_url is not a Discord host" do
      before { config.webhook_url = "https://evil.example.com/api/webhooks/1/token" }

      it { expect(config).not_to be_enabled }
    end

    context "when webhook_url is unparseable" do
      before { config.webhook_url = "not a url" }

      it { expect(config).not_to be_enabled }
    end

    context "when webhook_url is on discordapp.com" do
      before { config.webhook_url = "https://discordapp.com/api/webhooks/1/token" }

      it { expect(config).to be_enabled }
    end

    context "when webhook_url is on a discord.com subdomain" do
      before { config.webhook_url = "https://ptb.discord.com/api/webhooks/1/token" }

      it { expect(config).to be_enabled }
    end

    context "when webhook_url merely ends in discord.com" do
      before { config.webhook_url = "https://notdiscord.com/api/webhooks/1/token" }

      it { expect(config).not_to be_enabled }
    end
  end

  describe "#ignore?" do
    before { config.ignored_exceptions = ["ArgumentError"] }

    it { expect(config.ignore?(ArgumentError.new)).to be true }
    it { expect(config.ignore?(RuntimeError.new)).to be false }

    context "with a subclass of an ignored exception" do
      before { stub_const("MyBadArgument", Class.new(ArgumentError)) }

      it { expect(config.ignore?(MyBadArgument.new)).to be true }
    end

    context "with an exception class that is not loaded" do
      before { config.ignored_exceptions = ["Totally::Undefined::Error"] }

      it { expect(config.ignore?(RuntimeError.new)).to be false }
    end
  end

  describe "#logger" do
    it { expect(config.logger).to eq(Rails.logger) }

    context "when Rails has no logger" do
      before { Rails.logger = nil }

      it { expect(config.logger).to be_a(Logger) }
    end
  end
end
