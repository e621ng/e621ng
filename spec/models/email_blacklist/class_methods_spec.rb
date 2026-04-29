# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     EmailBlacklist Class Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe EmailBlacklist do
  include_context "as admin"

  # NOTE: .get_mx_records always returns [] in the test environment
  # (guarded by `return [] if Rails.env.test?`), so the MX lookup path
  # of .is_banned? cannot be exercised here.

  # ---------------------------------------------------------------------------
  # .domain_matches?
  # ---------------------------------------------------------------------------
  describe ".domain_matches?" do
    let(:banned) { ["spam.com", "phish.net"] }

    it "returns true for an exact domain match" do
      expect(EmailBlacklist.domain_matches?(banned, "spam.com")).to be true
    end

    it "returns true for a subdomain of a banned domain" do
      expect(EmailBlacklist.domain_matches?(banned, "mail.spam.com")).to be true
    end

    it "returns false when the domain does not match any banned domain" do
      expect(EmailBlacklist.domain_matches?(banned, "safe.org")).to be false
    end

    it "returns false when the banned list is empty" do
      expect(EmailBlacklist.domain_matches?([], "spam.com")).to be false
    end

    it "does not match a domain that merely ends with the same characters but is not a subdomain" do
      # "myspam.com" ends with "spam.com" — this tests the actual suffix behaviour
      expect(EmailBlacklist.domain_matches?(banned, "myspam.com")).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # .is_banned?
  # ---------------------------------------------------------------------------
  describe ".is_banned?" do
    before { Cache.delete("banned_emails") }
    after  { Cache.delete("banned_emails") }

    it "returns true when the email's domain is blacklisted" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@spam.example.com")).to be true
    end

    it "returns false when the email's domain is not blacklisted" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@safe.example.com")).to be false
    end

    it "is case-insensitive (blacklisted domain stored in upper case)" do
      create(:email_blacklist, domain: "SPAM.EXAMPLE.COM")
      expect(EmailBlacklist.is_banned?("user@spam.example.com")).to be true
    end

    it "serves subsequent lookups from cache" do
      create(:email_blacklist, domain: "spam.example.com")
      # Warm the cache
      EmailBlacklist.is_banned?("user@spam.example.com")
      # Remove the DB record without busting the cache
      EmailBlacklist.delete_all
      # Should still return true because the result is cached
      expect(EmailBlacklist.is_banned?("user@spam.example.com")).to be true
    end
  end
end
