# frozen_string_literal: true

require "timeout"

RSpec.describe RailsDiscordNotifier::Notifier do
  subject(:notifier) { described_class.new(config, client: client, clock: -> { now }) }

  let(:config)    { RailsDiscordNotifier.config }
  let(:client)    { instance_spy(RailsDiscordNotifier::Client, post: true) }
  let(:exception) { captured_exception }
  let(:env)       { Rack::MockRequest.env_for("https://app.example.com/articles") }
  let(:now)       { 0.0 }

  before { allow(config.logger).to receive(:error) }

  describe "delivery" do
    before { notifier.notify(exception, env: env) }

    it { expect(client).to have_received(:post) }
    it { expect(client).to have_received(:post).with(hash_including(:embeds)) }
  end

  describe "when disabled" do
    before do
      config.enabled = false
      notifier.notify(exception, env: env)
    end

    it { expect(client).not_to have_received(:post) }
  end

  describe "when the webhook url is missing" do
    before do
      config.webhook_url = nil
      notifier.notify(exception, env: env)
    end

    it { expect(client).not_to have_received(:post) }
  end

  describe "ignored exceptions" do
    before do
      config.ignored_exceptions = ["RuntimeError"]
      notifier.notify(exception, env: env)
    end

    it { expect(client).not_to have_received(:post) }
  end

  describe "throttling" do
    before { config.throttle_period = 60 }

    context "when the same error repeats inside the window" do
      before { 3.times { notifier.notify(captured_exception, env: env) } }

      it { expect(client).to have_received(:post).once }
    end

    context "when a different error occurs inside the window" do
      before do
        notifier.notify(exception, env: env)
        notifier.notify(captured_exception(ArgumentError, "different"), env: env)
      end

      it { expect(client).to have_received(:post).twice }
    end

    context "when the window has expired" do
      subject(:notifier) { described_class.new(config, client: client, clock: -> { clock_time.first }) }

      let(:clock_time) { [0.0] }

      before do
        notifier.notify(captured_exception, env: env)
        clock_time[0] = 61.0
        notifier.notify(captured_exception, env: env)
      end

      it { expect(client).to have_received(:post).twice }
    end

    context "when throttling is disabled" do
      before do
        config.throttle_period = 0
        3.times { notifier.notify(captured_exception, env: env) }
      end

      it { expect(client).to have_received(:post).exactly(3).times }
    end
  end

  describe "asynchronous delivery" do
    let(:threads) { Queue.new }
    let(:client) do
      instance_spy(RailsDiscordNotifier::Client).tap do |spy|
        allow(spy).to receive(:post) { threads << Thread.current }
      end
    end

    before { config.async = true }

    it "delivers on a thread other than the caller's" do
      notifier.notify(exception, env: env)
      expect(Timeout.timeout(5) { threads.pop }).not_to eq(Thread.current)
    end

    it "returns without waiting for the delivery thread" do
      expect(notifier.notify(exception, env: env)).to be_a(Thread)
    end
  end

  describe "#flush" do
    let(:threads) { Queue.new }
    let(:client) do
      instance_spy(RailsDiscordNotifier::Client).tap do |spy|
        allow(spy).to receive(:post) { threads << Thread.current }
      end
    end

    before do
      config.async = true
      notifier.notify(exception, env: env)
      notifier.flush
    end

    it { expect(client).to have_received(:post) }
    it { expect(threads.size).to eq(1) }
  end

  describe "#flush with nothing in flight" do
    it { expect { notifier.flush }.not_to raise_error }
  end

  describe "resilience" do
    context "when building the payload raises" do
      before { allow(RailsDiscordNotifier::Payload).to receive(:new).and_raise("payload exploded") }

      it { expect { notifier.notify(exception, env: env) }.not_to raise_error }

      it "logs the internal failure" do
        notifier.notify(exception, env: env)
        expect(config.logger).to have_received(:error).with(/payload exploded/)
      end
    end

    context "when the client raises" do
      before { allow(client).to receive(:post).and_raise("client exploded") }

      it { expect { notifier.notify(exception, env: env) }.not_to raise_error }
    end
  end

  describe "reporting the same exception object twice" do
    before do
      config.throttle_period = 0
      2.times { notifier.notify(exception, env: env) }
    end

    it { expect(client).to have_received(:post).once }
  end

  describe "reporting a frozen exception" do
    let(:exception) { captured_exception.freeze }

    it { expect { notifier.notify(exception, env: env) }.not_to raise_error }

    it "still delivers" do
      notifier.notify(exception, env: env)
      expect(client).to have_received(:post)
    end
  end

  describe "manual reporting without a request" do
    before { notifier.notify(exception, context: { "Job" => "ImportJob" }) }

    it { expect(client).to have_received(:post) }
  end
end
