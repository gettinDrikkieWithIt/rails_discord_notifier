# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::Middleware do
  subject(:middleware) { described_class.new(app, notifier: notifier) }

  let(:notifier) { instance_spy(RailsDiscordNotifier::Notifier) }
  let(:env)      { Rack::MockRequest.env_for("https://app.example.com/articles") }

  describe "when the application succeeds" do
    let(:app) { ->(_env) { [200, {}, ["ok"]] } }

    it { expect(middleware.call(env)).to eq([200, {}, ["ok"]]) }
    it { expect { middleware.call(env) }.not_to raise_error }

    it "does not notify" do
      middleware.call(env)
      expect(notifier).not_to have_received(:notify)
    end
  end

  describe "when the application raises" do
    let(:app) { ->(_env) { raise "boom!" } }

    it { expect { middleware.call(env) }.to raise_error(RuntimeError, "boom!") }

    it "notifies before re-raising" do
      suppress_exception { middleware.call(env) }
      expect(notifier).to have_received(:notify).with(instance_of(RuntimeError), env: env)
    end
  end

  describe "when notification itself fails" do
    let(:app) { ->(_env) { raise "boom!" } }

    before { allow(notifier).to receive(:notify).and_raise("notifier exploded") }

    it { expect { middleware.call(env) }.to raise_error(RuntimeError, "boom!") }
  end

  describe "the default notifier" do
    subject(:middleware) { described_class.new(app) }

    let(:app) { ->(_env) { [200, {}, []] } }

    it { expect { middleware.call(env) }.not_to raise_error }
  end

  def suppress_exception
    yield
  rescue StandardError
    nil
  end
end
