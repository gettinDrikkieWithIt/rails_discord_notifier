# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::CLI do
  subject(:cli) { described_class.new(argv, out: out, env: cli_env) }

  let(:out)     { StringIO.new }
  let(:argv)    { ["test"] }
  let(:url)     { "https://discord.com/api/webhooks/1/token" }
  let(:cli_env) { { "DISCORD_WEBHOOK_URL" => url } }

  describe "test command with a working webhook" do
    before do
      stub_request(:post, url).to_return(status: 204)
      cli.run
    end

    it { expect(a_request(:post, url)).to have_been_made }
    it { expect(out.string).to match(/sent/i) }
  end

  describe "test command exit status" do
    context "when Discord accepts the message" do
      before { stub_request(:post, url).to_return(status: 204) }

      it { expect(cli.run).to eq(0) }
    end

    context "when Discord rejects the message" do
      before { stub_request(:post, url).to_return(status: 400, body: "{}") }

      it { expect(cli.run).to eq(1) }
    end

    context "when the network fails" do
      before { stub_request(:post, url).to_raise(Errno::ECONNREFUSED) }

      it { expect(cli.run).to eq(1) }
    end
  end

  describe "the message it sends" do
    before do
      stub_request(:post, url).to_return(status: 204)
      cli.run
    end

    it { expect(a_request(:post, url).with { |r| r.body.include?("embeds") }).to have_been_made }
    it { expect(a_request(:post, url).with { |r| r.body.include?("RailsDiscordNotifier") }).to have_been_made }
  end

  describe "webhook given on the command line" do
    let(:argv)    { ["test", "--webhook", "https://discord.com/api/webhooks/2/other"] }
    let(:cli_env) { {} }

    before do
      stub_request(:post, "https://discord.com/api/webhooks/2/other").to_return(status: 204)
      cli.run
    end

    it { expect(a_request(:post, "https://discord.com/api/webhooks/2/other")).to have_been_made }
  end

  describe "without a webhook url" do
    let(:cli_env) { {} }

    before { cli.run }

    it { expect(cli.run).to eq(1) }
    it { expect(out.string).to include("DISCORD_WEBHOOK_URL") }
  end

  describe "with an invalid webhook url" do
    let(:cli_env) { { "DISCORD_WEBHOOK_URL" => "https://evil.example.com/hook" } }

    before { cli.run }

    it { expect(cli.run).to eq(1) }
    it { expect(out.string).to include("discord.com") }
  end

  describe "version command" do
    let(:argv) { ["version"] }

    before { cli.run }

    it { expect(out.string).to include(RailsDiscordNotifier::VERSION) }
    it { expect(cli.run).to eq(0) }
  end

  describe "help" do
    let(:argv) { [] }

    before { cli.run }

    it { expect(out.string).to match(/usage/i) }
    it { expect(cli.run).to eq(0) }
  end

  describe "an unknown command" do
    let(:argv) { ["wat"] }

    before { cli.run }

    it { expect(cli.run).to eq(1) }
    it { expect(out.string).to match(/usage/i) }
  end
end
