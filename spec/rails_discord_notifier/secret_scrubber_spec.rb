# frozen_string_literal: true

RSpec.describe RailsDiscordNotifier::SecretScrubber do
  subject(:scrubber) { described_class.new(%w[passw token _key]) }

  describe "#scrub" do
    it { expect(scrubber.scrub("token=abcd1234")).to eq("token=[FILTERED]") }
    it { expect(scrubber.scrub('password="hunter2"')).to eq("password=[FILTERED]") }
    it { expect(scrubber.scrub("Api_Key: sk_live_9999")).to eq("Api_Key: [FILTERED]") }
    it { expect(scrubber.scrub("user[password]=hunter2")).to eq("user[password]=[FILTERED]") }
    it { expect(scrubber.scrub("could not connect: password=x host=db")).to include("host=db") }
    it { expect(scrubber.scrub("password reset email sent")).to eq("password reset email sent") }
    it { expect(scrubber.scrub("no secrets here")).to eq("no secrets here") }
    it { expect(scrubber.scrub(nil)).to eq("") }
  end

  describe "credential shapes seen in real error messages" do
    subject(:scrubber) { described_class.new(%w[passw authorization]) }

    it { expect(scrubber.scrub("Authorization: Bearer eyJhbGciOi.abc")).to eq("Authorization: [FILTERED]") }
    it { expect(scrubber.scrub("authorization=Basic dXNlcjpwYXNz")).to eq("authorization=[FILTERED]") }
    it { expect(scrubber.scrub("Authorization: Token abc123secret")).to eq("Authorization: [FILTERED]") }
    it { expect(scrubber.scrub("Authorization: Digest abc123secret")).to eq("Authorization: [FILTERED]") }
    it { expect(scrubber.scrub('{"password":"hunter2","id":1}')).to eq('{"password":[FILTERED],"id":1}') }
    it { expect(scrubber.scrub('{"password" => "hunter2", "id" => 1}')).to eq('{"password" => [FILTERED], "id" => 1}') }
    it { expect(scrubber.scrub('{"password"=>"hunter2"}')).to eq('{"password"=>[FILTERED]}') }
  end

  describe "passwords inside URLs" do
    it { expect(scrubber.scrub("at redis://:s3cretpw@cache:6379")).to eq("at redis://:[FILTERED]@cache:6379") }
    it { expect(scrubber.scrub("postgres://app:Pass123@db/x")).to eq("postgres://app:[FILTERED]@db/x") }
    it { expect(scrubber.scrub("postgres://app:p@ss@db/x")).to eq("postgres://app:[FILTERED]@db/x") }
    it { expect(scrubber.scrub("see https://example.com:8080/a@b")).to eq("see https://example.com:8080/a@b") }
    it { expect(scrubber.scrub("https://api.example.com:8443?token=s3cr@t")).to eq("https://api.example.com:8443?token=[FILTERED]") }
    it { expect(scrubber.scrub("amqp://rabbit:5672,password=p@ssw0rd")).to eq("amqp://rabbit:5672,password=[FILTERED]") }
  end

  describe "text that is not valid UTF-8" do
    it { expect(scrubber.scrub("token=abc \xFF".b)).to eq("token=[FILTERED] \uFFFD") }
    it { expect(scrubber.scrub("bad \xFF")).to eq("bad \uFFFD") }
  end

  # Before Ruby 3.2, Onigmo backtracks in cubic time on these unless every
  # pattern is anchored and atomic. A request can put such text in a message.
  describe "long adversarial messages" do
    def elapsed
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    it { expect(elapsed { scrubber.scrub("token" * 2_000) }).to be < 1 }
    it { expect(elapsed { scrubber.scrub("a" * 10_000) }).to be < 1 }
  end

  describe "symbol matchers" do
    subject(:scrubber) { described_class.new(%i[secret]) }

    it { expect(scrubber.scrub("secret=shhh")).to eq("secret=[FILTERED]") }
  end

  describe "matchers that are not plain names" do
    subject(:scrubber) { described_class.new([/token/, ->(_k, v) { v }, "passw"]) }

    it { expect(scrubber.scrub("passw=x")).to eq("passw=[FILTERED]") }
    it { expect { scrubber.scrub("anything") }.not_to raise_error }
  end
end
