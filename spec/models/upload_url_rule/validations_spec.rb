# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadUrlRule do
  include_context "as admin"

  describe "validations" do
    it "has a valid factory" do
      expect(build(:upload_url_rule)).to be_valid
      expect(build(:blocking_upload_url_rule)).to be_valid
    end

    it "requires a label" do
      expect(build(:upload_url_rule, label: "")).not_to be_valid
    end

    it "requires a unique label, ignoring case" do
      create(:upload_url_rule, label: "Twitter sample")
      rule = build(:upload_url_rule, label: "twitter SAMPLE")
      expect(rule).not_to be_valid
      expect(rule.errors[:label]).to be_present
    end

    it "requires a pattern" do
      expect(build(:upload_url_rule, pattern: "")).not_to be_valid
    end

    it "rejects an unknown handling" do
      expect(build(:upload_url_rule, handling: "rewrite")).not_to be_valid
    end

    it "allows a blank replacement" do
      expect(build(:upload_url_rule, replacement: "")).to be_valid
    end

    it "rejects a pattern that does not compile" do
      rule = build(:upload_url_rule, pattern: "sample(")
      expect(rule).not_to be_valid
      expect(rule.errors[:pattern].first).to include("is invalid")
    end

    it "rejects a pattern that matches the empty string" do
      rule = build(:upload_url_rule, pattern: ".*", replacement: "")
      expect(rule).not_to be_valid
      expect(rule.errors[:pattern]).to include("must not match an empty string")
    end

    it "rejects a pattern with catastrophic backtracking" do
      rule = build(:upload_url_rule, pattern: "(a+)+\\1$", replacement: "")
      expect(rule).not_to be_valid
      expect(rule.errors[:pattern].first).to include("catastrophic backtracking")
    end

    it "rejects a replacement referring to a missing numbered group" do
      rule = build(:upload_url_rule, pattern: "(sample)/", replacement: "\\2/")
      expect(rule).not_to be_valid
      expect(rule.errors[:replacement]).to be_present
    end

    it "rejects a replacement referring to a missing named group" do
      rule = build(:upload_url_rule, pattern: "(?<kind>sample)/", replacement: "\\k<size>/")
      expect(rule).not_to be_valid
      expect(rule.errors[:replacement]).to be_present
    end

    it "accepts a replacement referring to existing groups" do
      expect(build(:upload_url_rule, pattern: "(sample)/(\\d+)", replacement: "full/\\2")).to be_valid
      expect(build(:upload_url_rule, pattern: "(?<kind>sample)/", replacement: "\\k<kind>-full/")).to be_valid
    end

    it "checks group references in an extended pattern ending in a comment" do
      expect(build(:upload_url_rule, pattern: "(?x) (sample) / # the sample dir", replacement: "\\1-full/")).to be_valid
      rule = build(:upload_url_rule, pattern: "(?x) (sample) / # the sample dir", replacement: "\\2/")
      expect(rule).not_to be_valid
      expect(rule.errors[:replacement]).to be_present
    end

    it "caps field lengths" do
      expect(build(:upload_url_rule, label: "a" * 101)).not_to be_valid
      expect(build(:upload_url_rule, pattern: "a" * 501)).not_to be_valid
      expect(build(:upload_url_rule, message: "a" * 501)).not_to be_valid
    end
  end
end
