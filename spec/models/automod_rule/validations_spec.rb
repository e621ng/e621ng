# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       AutomodRule Validations                               #
# --------------------------------------------------------------------------- #

RSpec.describe AutomodRule do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # name — presence
  # -------------------------------------------------------------------------
  describe "name — presence" do
    it "is invalid with a blank name" do
      rule = build(:automod_rule, name: "")
      expect(rule).not_to be_valid
      expect(rule.errors[:name]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # name — uniqueness (case-insensitive)
  # -------------------------------------------------------------------------
  describe "name — uniqueness" do
    it "is invalid when a rule with the same name already exists" do
      create(:automod_rule, name: "no_spam")
      rule = build(:automod_rule, name: "no_spam")
      expect(rule).not_to be_valid
      expect(rule.errors[:name]).to be_present
    end

    it "is invalid when a rule with the same name in a different case already exists" do
      create(:automod_rule, name: "no_spam")
      rule = build(:automod_rule, name: "NO_SPAM")
      expect(rule).not_to be_valid
      expect(rule.errors[:name]).to be_present
    end

    it "is valid when the name is distinct" do
      create(:automod_rule, name: "no_spam")
      rule = build(:automod_rule, name: "no_ads")
      expect(rule).to be_valid, rule.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # regex — presence
  # -------------------------------------------------------------------------
  describe "regex — presence" do
    it "is invalid with a blank regex" do
      rule = build(:automod_rule, regex: "")
      expect(rule).not_to be_valid
      expect(rule.errors[:regex]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # validate_regex — syntax
  # -------------------------------------------------------------------------
  describe "validate_regex — syntax" do
    it "is invalid with a syntactically broken regex" do
      rule = build(:automod_rule, regex: "[")
      expect(rule).not_to be_valid
      expect(rule.errors[:regex].join).to include("is invalid")
    end

    it "is valid with a well-formed regex" do
      rule = build(:automod_rule, regex: "\\bspam\\b")
      expect(rule).to be_valid, rule.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_regex — catastrophic backtracking
  # -------------------------------------------------------------------------
  describe "validate_regex — catastrophic backtracking" do
    it "is invalid when regex validation times out" do
      fake = instance_double(Regexp)
      allow(fake).to receive(:match?).and_raise(Regexp::TimeoutError)
      allow(Regexp).to receive(:new).and_return(fake)
      rule = build(:automod_rule, regex: "any_regex")
      expect(rule).not_to be_valid
      expect(rule.errors[:regex].join).to include("catastrophic backtracking")
    end
  end
end
