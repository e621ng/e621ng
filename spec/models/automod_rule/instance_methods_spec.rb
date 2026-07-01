# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     AutomodRule Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe AutomodRule do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    let!(:rule) { create(:automod_rule, regex: "spam") }

    it "returns true when the text matches the regex" do
      expect(rule.match?("this is spam content")).to be true
    end

    it "returns false when the text does not match the regex" do
      expect(rule.match?("completely clean content")).to be false
    end

    it "matches case-insensitively" do
      expect(rule.match?("This Is SPAM Content")).to be true
    end

    it "returns false when the compiled regex raises RegexpError" do
      fake = instance_double(Regexp)
      allow(fake).to receive(:match?).and_raise(RegexpError)
      allow(Regexp).to receive(:new).and_return(fake)
      expect(rule.match?("some text")).to be false
    end

    it "returns false when matching times out due to catastrophic backtracking" do
      fake = instance_double(Regexp)
      allow(fake).to receive(:match?).and_raise(Regexp::TimeoutError)
      allow(Regexp).to receive(:new).and_return(fake)
      expect(rule.match?("some text")).to be false
    end
  end
end
