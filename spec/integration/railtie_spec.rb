# frozen_string_literal: true

# Integration coverage for the Railtie against a genuinely booted Rails
# application (see spec/support/dummy_app.rb).
RSpec.describe "RailsDiscordNotifier::Railtie", type: :integration do
  let(:notifier) { instance_spy(RailsDiscordNotifier::Notifier) }

  before { allow(RailsDiscordNotifier).to receive(:notifier).and_return(notifier) }

  describe "the middleware stack" do
    it "includes the notifier middleware" do
      expect(Rails.application.middleware.map(&:klass)).to include(RailsDiscordNotifier::Middleware)
    end

    it "sits inside ShowExceptions so it sees the exception before Rails renders a 500" do
      stack = Rails.application.middleware.map(&:klass)
      expect(stack.index(RailsDiscordNotifier::Middleware)).to be > stack.index(ActionDispatch::ShowExceptions)
    end

    it "reports an exception raised by the application and re-raises it" do
      app = RailsDiscordNotifier::Middleware.new(->(_env) { raise "kaboom" })
      env = Rack::MockRequest.env_for("https://app.example.com/boom")

      expect { app.call(env) }.to raise_error(RuntimeError, "kaboom")
      expect(notifier).to have_received(:notify).with(instance_of(RuntimeError), env: env)
    end
  end

  # ActiveSupport::ErrorReporter only exists from Rails 7.0 onwards.
  describe "the Rails.error subscriber", if: RailsDiscordNotifier.error_reporter do
    it "reports errors recorded outside the request cycle" do
      expect do
        Rails.error.record { raise ArgumentError, "job failed" }
      end.to raise_error(ArgumentError)

      expect(notifier).to have_received(:notify).with(instance_of(ArgumentError), any_args)
    end

    it "reports errors handled by Rails.error.handle" do
      Rails.error.handle { raise "swallowed" }

      expect(notifier).to have_received(:notify).with(instance_of(RuntimeError), any_args)
    end
  end

  describe "the install generator" do
    it "is discoverable by rails generate" do
      require "generators/rails_discord_notifier/install_generator"
      expect(RailsDiscordNotifier::InstallGenerator.namespace).to eq("rails_discord_notifier:install")
    end
  end
end
