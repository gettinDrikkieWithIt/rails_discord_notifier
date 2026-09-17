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
