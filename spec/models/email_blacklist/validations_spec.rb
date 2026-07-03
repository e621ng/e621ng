# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      EmailBlacklist Validations                             #
# --------------------------------------------------------------------------- #

RSpec.describe EmailBlacklist do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # domain presence
  # ---------------------------------------------------------------------------
  describe "domain presence" do
    it "is invalid when domain is blank" do
      record = build(:email_blacklist, domain: "")
      expect(record).not_to be_valid
      expect(record.errors[:domain]).to be_present
    end

    it "is valid when domain is present" do
      expect(build(:email_blacklist, domain: "spam.example.com")).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # domain uniqueness
  # ---------------------------------------------------------------------------
  describe "domain uniqueness" do
    it "is invalid when a blacklist entry with the same domain already exists" do
      create(:email_blacklist, domain: "duplicate.example.com")
      record = build(:email_blacklist, domain: "duplicate.example.com")
      expect(record).not_to be_valid
      expect(record.errors[:domain]).to include("already exists")
    end

    it "is invalid when a blacklist entry with the same domain exists in a different case" do
      create(:email_blacklist, domain: "spam.example.com")
      record = build(:email_blacklist, domain: "SPAM.EXAMPLE.COM")
      expect(record).not_to be_valid
      expect(record.errors[:domain]).to include("already exists")
    end

    it "is valid when the domain is unique" do
      create(:email_blacklist, domain: "other.example.com")
      expect(build(:email_blacklist, domain: "different.example.com")).to be_valid
    end
  end
end
