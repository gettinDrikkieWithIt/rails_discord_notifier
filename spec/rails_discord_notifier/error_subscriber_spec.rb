# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::ErrorSubscriber do
  subject(:subscriber) { described_class.new(notifier: notifier) }

  let(:notifier)  { instance_spy(RailsDiscordNotifier::Notifier) }
  let(:exception) { captured_exception }
  let(:env)       { Rack::MockRequest.env_for("https://app.example.com/articles") }

  describe "#report" do
    before { subscriber.report(exception, handled: false, severity: :error, context: {}, source: "job.active_job") }

    it { expect(notifier).to have_received(:notify).with(exception, any_args) }

    it {
      expect(notifier).to have_received(:notify).with(anything,
                                                      hash_including(context: hash_including("Source" => "job.active_job")))
    }

    it {
      expect(notifier).to have_received(:notify).with(anything, hash_including(context: hash_including("Severity" => "error")))
    }
  end

  describe "when the context carries a Rack env" do
    before { subscriber.report(exception, handled: false, severity: :error, context: { env: env }) }

    it { expect(notifier).to have_received(:notify).with(anything, hash_including(env: env)) }
  end

  describe "when called without a source (Rails 7.0 signature)" do
    it { expect { subscriber.report(exception, handled: true, severity: :warning, context: {}) }.not_to raise_error }
  end

  describe "when extra context keys are present" do
    before { subscriber.report(exception, handled: false, severity: :error, context: { tenant: "acme" }) }

    it { expect(notifier).to have_received(:notify).with(anything, hash_including(context: hash_including("tenant" => "acme"))) }
  end

  describe "when notification fails" do
    before { allow(notifier).to receive(:notify).and_raise("exploded") }

    it { expect { subscriber.report(exception, handled: false, severity: :error, context: {}) }.not_to raise_error }
  end
end
