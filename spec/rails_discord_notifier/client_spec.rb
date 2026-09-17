# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::Client do
  subject(:client) { described_class.new(config) }

  let(:config)  { RailsDiscordNotifier.config }
  let(:url)     { "https://discord.com/api/webhooks/1/token" }
  let(:payload) { { username: "Error Bot", embeds: [{ title: "boom" }] } }
  let(:sockets) { [] }

  before do
    allow(config.logger).to receive(:error)
    allow(config.logger).to receive(:warn)
    allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { |http| sockets << http }
    end
  end

  describe "a successful delivery" do
    before do
      stub_request(:post, url).to_return(status: 204)
      client.post(payload)
    end

    it { expect(a_request(:post, url).with(body: JSON.generate(payload))).to have_been_made }
    it { expect(a_request(:post, url).with(headers: { "Content-Type" => "application/json" })).to have_been_made }
    it { expect(sockets.first.open_timeout).to eq(2) }
    it { expect(sockets.first.read_timeout).to eq(5) }
    it { expect(sockets.first.write_timeout).to eq(5) }
    it { expect(sockets.first.use_ssl?).to be true }
    it { expect(config.logger).not_to have_received(:error) }
  end

  describe "#post return value" do
    context "when Discord accepts the message" do
      before { stub_request(:post, url).to_return(status: 204) }

      it { expect(client.post(payload)).to be true }
    end

    context "when Discord rejects the message" do
      before { stub_request(:post, url).to_return(status: 400, body: '{"embeds":["too long"]}') }

      it { expect(client.post(payload)).to be false }
    end
  end

  describe "timeouts honour configuration" do
    before do
      config.open_timeout = 7
      config.read_timeout = 9
      config.write_timeout = 11
      stub_request(:post, url).to_return(status: 204)
      client.post(payload)
    end

    it { expect(sockets.first.open_timeout).to eq(7) }
    it { expect(sockets.first.read_timeout).to eq(9) }
    it { expect(sockets.first.write_timeout).to eq(11) }
  end

  describe "when Discord rejects the payload" do
    before do
      stub_request(:post, url).to_return(status: 400, body: '{"embeds":["Must be 1024 or fewer in length."]}')
      client.post(payload)
    end

    it { expect(config.logger).to have_received(:error).with(/400/) }
    it { expect(config.logger).to have_received(:error).with(/1024 or fewer/) }
  end

  describe "when Discord rate limits" do
    before do
      stub_request(:post, url).to_return(status: 429, body: "{}", headers: { "Retry-After" => "3" })
      client.post(payload)
    end

    it { expect(config.logger).to have_received(:warn).with(/rate limited/i) }
    it { expect(config.logger).to have_received(:warn).with(/3/) }
  end

  describe "when the network fails" do
    before { stub_request(:post, url).to_raise(Errno::ECONNREFUSED) }

    it { expect { client.post(payload) }.not_to raise_error }
    it { expect(client.post(payload)).to be false }

    it "logs the failure" do
      client.post(payload)
      expect(config.logger).to have_received(:error).with(/ECONNREFUSED/)
    end
  end

  describe "when the request times out" do
    before { stub_request(:post, url).to_timeout }

    it { expect { client.post(payload) }.not_to raise_error }
    it { expect(client.post(payload)).to be false }
  end

  describe "when the webhook url is unusable" do
    before { config.webhook_url = nil }

    it { expect(client.post(payload)).to be false }
    it { expect { client.post(payload) }.not_to raise_error }
  end
end
