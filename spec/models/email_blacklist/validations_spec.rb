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

  # ---------------------------------------------------------------------------
  # domain format
  # ---------------------------------------------------------------------------
  describe "domain format" do
    it "is valid with a plain domain" do
      expect(build(:email_blacklist, domain: "example.com")).to be_valid
    end

    it "is valid with a bare TLD" do
      expect(build(:email_blacklist, domain: "info")).to be_valid
    end

    it "is valid with a subdomain and hyphens" do
      expect(build(:email_blacklist, domain: "mail-1.spam.example.com")).to be_valid
    end

    it "is valid with a punycode label" do
      expect(build(:email_blacklist, domain: "xn--bcher-kva.example")).to be_valid
    end

    it "is invalid when blank" do
      expect(build(:email_blacklist, domain: nil)).not_to be_valid
      expect(build(:email_blacklist, domain: "")).not_to be_valid
      expect(build(:email_blacklist, domain: "  ")).not_to be_valid
    end

    it "rejects entries that are not plain domain names" do
      [
        "*mail.com",       # wildcard
        "*.mail.com",
        "%.com",           # SQL LIKE wildcard
        "my_domain.com",   # underscore (LIKE wildcard, invalid in hostnames)
        "@tmail.com",      # email-style prefix
        "user@tmail.com",
        ".tmail.com",      # leading dot
        "tmail..com",      # empty label
        "tmail.com/path",
        "tmail com",       # whitespace inside
        "back\\slash.com",
        "-tmail.com",      # label starts with hyphen
        "tmail-.com",      # label ends with hyphen
        "bücher.example",  # non-ASCII; must be punycode
      ].each do |bad|
        record = build(:email_blacklist, domain: bad)
        expect(record).not_to be_valid, "expected #{bad.inspect} to be invalid"
        expect(record.errors[:domain]).to be_present
      end
    end

    it "rejects a domain longer than 253 characters" do
      long = "#{(['a' * 60] * 5).join('.')}.com"
      expect(long.length).to be > 253
      expect(build(:email_blacklist, domain: long)).not_to be_valid
    end

    it "rejects a label longer than 63 characters" do
      expect(build(:email_blacklist, domain: "#{'a' * 64}.com")).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # domain normalization
  # ---------------------------------------------------------------------------
  describe "domain normalization" do
    it "downcases, strips whitespace and removes a trailing dot" do
      record = build(:email_blacklist, domain: "  TMail.Com. ")
      expect(record).to be_valid
      expect(record.domain).to eq("tmail.com")
    end

    it "still rejects whitespace inside the domain" do
      expect(build(:email_blacklist, domain: "tmail .com")).not_to be_valid
    end
  end
end
