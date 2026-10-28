# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::Payload do
  subject(:payload) { described_class.new(exception, env: env, config: config).to_h }

  let(:config)    { RailsDiscordNotifier.config }
  let(:exception) { captured_exception }
  let(:env)       { Rack::MockRequest.env_for("https://app.example.com/articles") }
  let(:embed)     { payload[:embeds].first }
  let(:fields)    { embed[:fields] }
  let(:app_frame) { "#{Rails.root}/app/jobs/import_job.rb:12:in 'ImportJob#perform'" }
  let(:gem_frame) { "#{Gem.default_dir}/gems/sidekiq-7.3.10/lib/sidekiq/processor.rb:140:in 'Module#const_get'" }

  def field_value(name)
    fields.find { |f| f[:name] == name }&.fetch(:value)
  end

  describe "identity" do
    before { config.username = "Boom Bot" }

    it { expect(payload[:username]).to eq("Boom Bot") }
  end

  describe "the embed" do
    it { expect(embed[:title]).to eq("Exception in GET /articles") }
    it { expect(embed[:description]).to include("RuntimeError") }
    it { expect(embed[:description]).to include("boom") }
    it { expect(embed[:color]).to eq(16_711_680) }

    it "uses Discord's native timestamp instead of a field" do
      expect(embed[:timestamp]).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it { expect(field_value("Timestamp")).to be_nil }
  end

  describe "secret redaction" do
    let(:env) do
      Rack::MockRequest.env_for(
        "https://app.example.com/users?api_key=SUPERSECRET&q=hi",
        method: "POST",
        input: "user[password]=hunter2&user[profile][token]=abc123&note=keep",
        "CONTENT_TYPE" => "application/x-www-form-urlencoded"
      )
    end

    it { expect(field_value("Params")).not_to include("hunter2") }
    it { expect(field_value("Params")).not_to include("abc123") }
    it { expect(field_value("Params")).to include("keep") }
    it { expect(field_value("URL")).to eq("https://app.example.com/users") }
    it { expect(field_value("Params")).to include('"q": "hi"') }
    it { expect(payload.to_s).not_to include("SUPERSECRET") }
    it { expect(payload.to_s).not_to include("hunter2") }

    context "when the app defines its own filter_parameters" do
      before { Rails.application.config.filter_parameters = [:note] }

      it { expect(field_value("Params")).not_to include("keep") }
    end
  end

  describe "Discord size limits" do
    let(:long_body) { "article[body]=#{"lorem+ipsum+" * 300}&article[title]=t" }
    let(:env) do
      Rack::MockRequest.env_for("https://app.example.com/articles", method: "POST",
                                                                    input: long_body,
                                                                    "CONTENT_TYPE" => "application/x-www-form-urlencoded")
    end

    it { expect(field_value("Params").length).to be <= 1024 }
    it { expect(fields.map { |f| f[:value].to_s.length }).to all(be <= 1024) }
    it { expect(fields.map { |f| f[:name].to_s.length }).to all(be <= 256) }
    it { expect(fields.length).to be <= 25 }
    it { expect(embed[:title].length).to be <= 256 }
    it { expect(embed[:description].length).to be <= 4096 }

    it "keeps the whole embed under Discord's 6000 character budget" do
      expect(described_class.new(exception, env: env, config: config).size).to be <= 6000
    end

    it "leaves the code fence intact when it truncates params" do
      expect(field_value("Params")).to end_with("```")
    end

    context "with a very long exception message" do
      let(:exception) do
        exception_with_backtrace(["a.rb:1:in `x'"]).tap do |e|
          e.define_singleton_method(:message) do
            "x" * 9000
          end
        end
      end

      it { expect(embed[:description].length).to be <= 4096 }
    end

    context "with a very long request path" do
      let(:env) { Rack::MockRequest.env_for("https://app.example.com/#{"seg/" * 300}") }

      it { expect(embed[:title].length).to be <= 256 }
    end

    context "with a deep backtrace" do
      let(:exception) do
        exception_with_backtrace(Array.new(200) do |i|
          "/a/very/long/application/path/segment/file_#{i}.rb:#{i}:in `method_#{i}'"
        end)
      end

      it { expect(field_value("Backtrace").length).to be <= 1024 }
      it { expect(field_value("Backtrace")).to include("file_0.rb") }
    end
  end

  describe "when context crowds out the other fields" do
    subject(:payload) { described_class.new(exception, env: env, config: config, context: context).to_h }

    let(:context) { (1..30).to_h { |i| ["Key#{i}", "value"] } }

    it { expect(fields.length).to be <= 25 }
    it { expect(fields.map { |f| f[:name] }).to include("Backtrace") }
  end

  describe "when context values are enormous" do
    subject(:payload) { described_class.new(exception, env: env, config: config, context: context) }

    let(:context) { (1..8).to_h { |i| ["Ctx#{i}", "x" * 2000] } }

    it { expect(payload.size).to be <= 6000 }
    it { expect(payload.to_h[:embeds].first[:fields].map { |f| f[:name] }).to include("Backtrace") }
  end

  describe "secrets inside the exception message" do
    let(:exception) { captured_exception(RuntimeError, "auth failed for token=abcd1234secret") }

    it { expect(embed[:description]).not_to include("abcd1234secret") }
    it { expect(embed[:description]).to include("[FILTERED]") }
    it { expect(embed[:description]).to include("auth failed") }

    context "with a database connection error" do
      let(:exception) { captured_exception(RuntimeError, 'could not connect: password="hunter2" host=db') }

      it { expect(embed[:description]).not_to include("hunter2") }
    end

    context "with a colon-separated secret" do
      let(:exception) { captured_exception(RuntimeError, "Api_Key: sk_live_9999") }

      it { expect(embed[:description]).not_to include("sk_live_9999") }
    end

    context "with an innocuous message" do
      let(:exception) { captured_exception(RuntimeError, "password reset email could not be sent") }

      it { expect(embed[:description]).to include("password reset email could not be sent") }
    end

    context "when the cause carries the secret" do
      let(:exception) do
        raise ArgumentError, "bad token=abcd1234secret"
      rescue ArgumentError
        captured_exception(RuntimeError, "wrapper")
      end

      it { expect(embed[:description]).not_to include("abcd1234secret") }
    end
  end

  # Rack hands header values over as binary strings, and a message can carry
  # any bytes. Neither may make the report fail to serialize and be dropped.
  describe "text that is not valid UTF-8" do
    context "with a binary User-Agent" do
      let(:env) { Rack::MockRequest.env_for("https://app.example.com/articles", "HTTP_USER_AGENT" => "Mozilla \xFF".b) }

      it { expect { JSON.generate(payload) }.not_to raise_error }
      it { expect(field_value("User Agent")).to eq("Mozilla \uFFFD") }
    end

    context "with a message in another valid encoding" do
      let(:exception) { captured_exception(RuntimeError, "Caf\xE9 closed".dup.force_encoding(Encoding::Windows_1252)) }

      it { expect(embed[:description]).to include("Café closed") }
    end

    context "with an invalid byte in the exception message" do
      let(:exception) { captured_exception(RuntimeError, "bad \xFF") }

      it { expect(embed[:description]).to include("bad \uFFFD") }
    end
  end

  describe "backtrace handling" do
    # BACKTRACE=1 is Rails' switch for skipping the cleaner while debugging.
    before { stub_const("ENV", ENV.to_h.except("BACKTRACE")) }

    context "when the exception has no backtrace" do
      let(:exception) { RuntimeError.new("boom") }

      it { expect(field_value("Backtrace")).to eq("No backtrace available") }
    end

    context "with app and library frames" do
      let(:exception) { exception_with_backtrace([gem_frame, app_frame]) }

      it { expect(field_value("Backtrace")).to eq("`app/jobs/import_job.rb:12:in 'ImportJob#perform'`") }
    end

    context "with library frames only" do
      let(:exception) { exception_with_backtrace([gem_frame]) }

      it { expect(field_value("Backtrace")).to eq("`sidekiq (7.3.10) lib/sidekiq/processor.rb:140:in 'Module#const_get'`") }
    end

    context "with more app frames than backtrace_lines" do
      let(:exception) { exception_with_backtrace([app_frame, app_frame.sub(":12:", ":13:")]) }

      before { config.backtrace_lines = 1 }

      it { expect(field_value("Backtrace")).to eq("`app/jobs/import_job.rb:12:in 'ImportJob#perform'`") }
    end

    # Rails 6.1 and 7.0 build the cleaner around "#{Rails.root}/", which is "/"
    # without an app, so it would strip the leading slash from every path.
    context "when Rails has no app root" do
      let(:exception) { exception_with_backtrace([gem_frame]) }

      before { allow(Rails).to receive(:root).and_return(nil) }

      it { expect(field_value("Backtrace")).to eq("`#{gem_frame}`") }
    end

    context "when Rails is not loaded" do
      let(:env)       { nil }
      let(:exception) { exception_with_backtrace([gem_frame]) }

      before { hide_const("Rails") }

      it { expect(field_value("Backtrace")).to eq("`#{gem_frame}`") }
    end

    # A custom silencer in the host app must not cost the whole report.
    context "when the backtrace cleaner raises" do
      let(:exception) { exception_with_backtrace([gem_frame]) }

      before { allow(Rails.backtrace_cleaner).to receive(:clean).and_raise("cleaner blew up") }

      it { expect(field_value("Backtrace")).to eq("`#{gem_frame}`") }
    end
  end

  describe "host" do
    context "when running on a Heroku dyno" do
      before { stub_const("ENV", ENV.to_h.merge("DYNO" => "worker.1")) }

      it { expect(field_value("Host")).to eq("worker.1") }
    end

    context "when not on Heroku" do
      before { stub_const("ENV", ENV.to_h.except("DYNO")) }

      it { expect(field_value("Host")).to eq(Socket.gethostname) }
    end
  end

  describe "cause chain" do
    let(:exception) do
      raise ArgumentError, "the root cause"
    rescue ArgumentError
      captured_exception(RuntimeError, "the wrapper")
    end

    it { expect(embed[:description]).to include("the root cause") }
    it { expect(embed[:description]).to include("ArgumentError") }
  end

  describe "request context" do
    let(:env) do
      Rack::MockRequest.env_for("https://app.example.com/articles").merge(
        "action_dispatch.request.parameters" => { "controller" => "articles", "action" => "show" },
        "action_dispatch.request_id" => "req-123",
        "HTTP_USER_AGENT" => "RSpec/1.0"
      )
    end

    it { expect(field_value("Controller")).to eq("articles") }
    it { expect(field_value("Action")).to eq("show") }
    it { expect(field_value("Request ID")).to eq("req-123") }
    it { expect(field_value("User Agent")).to eq("RSpec/1.0") }
    it { expect(field_value("Environment")).to eq("test") }
    it { expect(field_value("Host")).not_to be_nil }
  end

  describe "release" do
    context "when configured" do
      before { config.release = "abc1234" }

      it { expect(field_value("Release")).to eq("abc1234") }
    end

    context "when not configured" do
      it { expect(field_value("Release")).to be_nil }
    end
  end

  describe "include_params" do
    let(:env) { Rack::MockRequest.env_for("https://app.example.com/search?email=jane%40example.com") }

    before { config.include_params = false }

    it { expect(field_value("Params")).to be_nil }
    it { expect(payload.to_s).not_to include("jane") }
  end

  describe "custom context" do
    context "when config.context returns a hash" do
      before { config.context = ->(_env) { { "User" => "42" } } }

      it { expect(field_value("User")).to eq("42") }
    end

    context "when config.context raises" do
      before { config.context = ->(_env) { raise "context blew up" } }

      it { expect { payload }.not_to raise_error }
    end

    context "when config.context returns a secret" do
      before { config.context = ->(_env) { { "api_token" => "tok_123" } } }

      it { expect(field_value("api_token")).to eq("[FILTERED]") }
    end

    context "when passed context carries a secret" do
      subject(:payload) { described_class.new(exception, env: env, config: config, context: { password: "hunter2" }).to_h }

      it { expect(field_value("password")).to eq("[FILTERED]") }
      it { expect(payload.to_s).not_to include("hunter2") }
    end

    # The Rails guides' own example filter assumes string values.
    context "when a filter Proc raises on a context value" do
      before do
        config.filter_parameters = [->(key, value) { value.reverse! if key.to_s.include?("card") }]
        config.context = ->(_env) { { "card_count" => 3 } }
      end

      it { expect(field_value("Backtrace")).not_to be_nil }
      it { expect(field_value("card_count")).to be_nil }
    end

    # Rails.error.report(e, context: { params: params }) hands over a
    # Parameters object, which ParameterFilter does not walk into on its own.
    context "when context carries ActionController::Parameters" do
      subject(:payload) do
        described_class.new(exception, env: env, config: config,
                                       context: { params: ActionController::Parameters.new("password" => "hunter2") }).to_h
      end

      it { expect(payload.to_s).not_to include("hunter2") }
    end

    context "when the filter cannot process the context" do
      before do
        allow(config.logger).to receive(:warn)
        config.filter_parameters = [->(key, value) { value.reverse! if key.to_s.include?("card") }]
        config.context = ->(_env) { { "card_count" => 3 } }
        payload
      end

      it { expect(config.logger).to have_received(:warn).with(/context/) }
    end

    context "when context is passed directly" do
      subject(:payload) { described_class.new(exception, env: env, config: config, context: { "Job" => "ImportJob" }).to_h }

      it { expect(field_value("Job")).to eq("ImportJob") }
    end
  end

  describe "without a request" do
    let(:env) { nil }

    it { expect(embed[:title]).to eq("RuntimeError") }
    it { expect(field_value("URL")).to be_nil }
    it { expect(field_value("Backtrace")).not_to be_nil }
    it { expect(field_value("Environment")).to eq("test") }
  end

  describe "when params cannot be parsed" do
    let(:env) do
      Rack::MockRequest.env_for("https://app.example.com/x", method: "POST", input: "a[]=1&a[b]=2",
                                                             "CONTENT_TYPE" => "application/x-www-form-urlencoded")
    end

    it { expect { payload }.not_to raise_error }
  end

  describe "#fingerprint" do
    subject(:fingerprint) { fingerprint_for(exception, "/articles/1") }

    def fingerprint_for(error, path, action: "show")
      env = Rack::MockRequest.env_for("https://app.example.com#{path}")
                             .merge("action_dispatch.request.parameters" => { "controller" => "articles", "action" => action })
      described_class.new(error, env: env, config: config).fingerprint
    end

    it { is_expected.to be_a(String) }
    it { is_expected.to eq(fingerprint_for(exception, "/articles/1")) }
    it { is_expected.to eq(fingerprint_for(exception, "/articles/2")) }
    it { is_expected.not_to eq(fingerprint_for(exception, "/articles/1", action: "edit")) }
    it { is_expected.not_to eq(fingerprint_for(captured_exception(ArgumentError, "boom"), "/articles/1")) }
  end
end
