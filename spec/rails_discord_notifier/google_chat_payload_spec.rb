# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::GoogleChatPayload do
  subject(:payload) { described_class.new(exception, env: env, config: config, context: context).to_h }

  let(:config)    { RailsDiscordNotifier.config }
  let(:exception) { exception_with_backtrace(["app/models/order.rb:7:in `save'", "app/controllers/orders_controller.rb:42"]) }
  let(:env)       { Rack::MockRequest.env_for("https://app.example.com/articles") }
  let(:context)   { {} }
  let(:text)      { payload[:text] }

  describe "the message body" do
    before { config.username = "Boom Bot" }

    it { expect(payload.keys).to eq([:text]) }
  end

  describe "the heading" do
    it { expect(text).to start_with("*Exception in GET /articles*\n*RuntimeError*: boom\n") }

    context "without a request" do
      let(:env) { nil }

      it { expect(text).to start_with("*RuntimeError*\n") }
    end

    context "with a cause" do
      let(:exception) do
        raise ArgumentError, "the root cause"
      rescue ArgumentError
        captured_exception(RuntimeError, "the wrapper")
      end

      it { expect(text).to include("Caused by *ArgumentError*: the root cause") }
    end
  end

  describe "single-line fields" do
    before { config.release = "abc1234" }

    it { expect(text).to include("\n*URL:* https://app.example.com/articles\n") }
    it { expect(text).to include("\n*Release:* abc1234\n") }
    it { expect(text).to include("\n*Environment:* test\n") }
  end

  describe "the backtrace" do
    let(:code_block) { "```\napp/models/order.rb:7:in `save'\napp/controllers/orders_controller.rb:42\n```" }

    it { expect(text).to end_with("*Backtrace:*\n#{code_block}") }

    context "when it is very deep" do
      let(:exception) do
        exception_with_backtrace(Array.new(200) { |i| "/a/very/long/application/path/file_#{i}.rb:#{i}:in `m_#{i}'" })
      end

      it { expect(text).to include("file_0.rb") }
      it { expect(text).to end_with("\n```") }
    end

    context "when there is none" do
      let(:exception) { RuntimeError.new("boom") }

      it { expect(text).to end_with("*Backtrace:* No backtrace available") }
    end
  end

  describe "params" do
    let(:env) do
      Rack::MockRequest.env_for(
        "https://app.example.com/users?api_key=SUPERSECRET&q=hi",
        method: "POST",
        input: "user[password]=hunter2&note=keep",
        "CONTENT_TYPE" => "application/x-www-form-urlencoded"
      )
    end

    it { expect(text).to include("*Params:*\n```\n{") }
    it { expect(text).not_to include("```json") }
    it { expect(text).to include("keep") }
    it { expect(text).not_to include("hunter2") }
    it { expect(text).not_to include("SUPERSECRET") }
  end

  describe "a secret in the exception message" do
    let(:exception) { captured_exception(RuntimeError, "auth failed for token=abcd1234secret") }

    it { expect(text).not_to include("abcd1234secret") }
  end

  # Anyone who can make the app raise controls the message, the path and the
  # User-Agent, and must not be able to @all the space or plant a masked link.
  describe "chat markup in attacker-controlled text" do
    context "with a mention in the exception message" do
      let(:exception) { captured_exception(RuntimeError, "invalid name <users/all>") }

      it { expect(text).not_to include("<users/all>") }
      it { expect(text).to include("users/all") }
    end

    context "with a masked link in the User-Agent" do
      let(:env) do
        Rack::MockRequest.env_for("https://app.example.com/articles",
                                  "HTTP_USER_AGENT" => "<https://evil.example|Reset your password>")
      end

      it { expect(text).not_to include("<https://evil.example") }
    end

    context "with a mention in the request path" do
      let(:env) { Rack::MockRequest.env_for("https://app.example.com/").merge("PATH_INFO" => "/<users/all>") }

      it { expect(text).not_to include("<users/all>") }
    end
  end

  describe "Google Chat's 32,000 byte message limit" do
    let(:context) { (1..30).to_h { |i| ["Ctx#{i}", "😀<" * 3000] } }
    let(:exception) { captured_exception(RuntimeError, "😀<" * 9000) }

    it { expect(text.bytesize).to be <= 32_000 }
    it { expect(text).to include("*Backtrace:*") }
  end
end
