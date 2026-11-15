# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     EmailBlacklist Class Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe EmailBlacklist do
  include_context "as admin"

  # NOTE: .get_mx_records always returns [] in local/test environments
  # (guarded by `return [] if Rails.env.local?`), so the MX specs below stub
  # it instead of hitting DNS.

  # ---------------------------------------------------------------------------
  # .normalize_domain
  # ---------------------------------------------------------------------------
  describe ".normalize_domain" do
    it "strips whitespace, downcases and removes a trailing dot" do
      expect(EmailBlacklist.normalize_domain("  SPAM.Com. ")).to eq("spam.com")
    end

    it "returns an empty string for nil" do
      expect(EmailBlacklist.normalize_domain(nil)).to eq("")
    end
  end

  # ---------------------------------------------------------------------------
  # .domain_matches?
  # ---------------------------------------------------------------------------
  describe ".domain_matches?" do
    let(:banned) { Set.new(["spam.com", "phish.net"]) }

    it "returns true for an exact domain match" do
      expect(EmailBlacklist.domain_matches?(banned, "spam.com")).to be true
    end

    it "returns true for a subdomain of a banned domain" do
      expect(EmailBlacklist.domain_matches?(banned, "mail.spam.com")).to be true
    end

    it "returns true for a deeply nested subdomain" do
      expect(EmailBlacklist.domain_matches?(banned, "a.b.c.spam.com")).to be true
    end

    it "returns false when the domain does not match any banned domain" do
      expect(EmailBlacklist.domain_matches?(banned, "safe.org")).to be false
    end

    it "returns false when the banned set is empty" do
      expect(EmailBlacklist.domain_matches?(Set.new, "spam.com")).to be false
    end

    it "does not match a domain that merely ends with the same characters" do
      # "myspam.com" ends with the string "spam.com" but is a different domain.
      expect(EmailBlacklist.domain_matches?(banned, "myspam.com")).to be false
    end

    it "does not ban hotmail.com because of a tmail.com entry" do
      banned = Set.new(["tmail.com"])
      expect(EmailBlacklist.domain_matches?(banned, "tmail.com")).to be true
      expect(EmailBlacklist.domain_matches?(banned, "mx.tmail.com")).to be true
      expect(EmailBlacklist.domain_matches?(banned, "hotmail.com")).to be false
    end

    it "does not match a banned domain that is only a prefix of the label" do
      expect(EmailBlacklist.domain_matches?(banned, "spam.com.evil.org")).to be false
    end

    it "never matches on a bare TLD entry" do
      banned = Set.new(["com"])
      expect(EmailBlacklist.domain_matches?(banned, "example.com")).to be false
    end

    it "is case-insensitive and ignores a trailing dot on the domain" do
      expect(EmailBlacklist.domain_matches?(banned, "MAIL.SPAM.COM.")).to be true
    end

    it "returns false for a blank domain" do
      expect(EmailBlacklist.domain_matches?(banned, "")).to be false
      expect(EmailBlacklist.domain_matches?(banned, nil)).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # .is_banned?
  # ---------------------------------------------------------------------------
  describe ".is_banned?" do
    before { Cache.delete(EmailBlacklist::BANNED_CACHE_KEY) }
    after  { Cache.delete(EmailBlacklist::BANNED_CACHE_KEY) }

    it "returns true when the email's domain is blacklisted" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@spam.example.com")).to be true
    end

    it "returns true for a subdomain of a blacklisted domain" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@mx.spam.example.com")).to be true
    end

    it "returns false when the email's domain is not blacklisted" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@safe.example.com")).to be false
    end

    it "is case-insensitive (blacklisted domain stored in upper case)" do
      create(:email_blacklist, domain: "SPAM.EXAMPLE.COM")
      expect(EmailBlacklist.is_banned?("user@spam.example.com")).to be true
    end

    it "is case-insensitive (email domain in upper case)" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@SPAM.EXAMPLE.COM")).to be true
    end

    it "ignores whitespace around a stored domain" do
      create(:email_blacklist, domain: "  spam.example.com  ")
      expect(EmailBlacklist.is_banned?("user@spam.example.com")).to be true
    end

    it "matches an email domain with a trailing dot" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?("user@spam.example.com.")).to be true
    end

    it "does not ban unrelated domains that merely end with a blacklisted entry" do
      # Regression: a "tmail.com" entry used to ban every @hotmail.com address
      create(:email_blacklist, domain: "tmail.com")
      expect(EmailBlacklist.is_banned?("a@tmail.com")).to be true
      expect(EmailBlacklist.is_banned?("a@mx.tmail.com")).to be true
      expect(EmailBlacklist.is_banned?("a@hotmail.com")).to be false
    end

    it "returns false for malformed emails" do
      create(:email_blacklist, domain: "spam.example.com")
      expect(EmailBlacklist.is_banned?(nil)).to be false
      expect(EmailBlacklist.is_banned?("")).to be false
      expect(EmailBlacklist.is_banned?("no-at-sign")).to be false
      expect(EmailBlacklist.is_banned?("user@")).to be false
      expect(EmailBlacklist.is_banned?("@spam.example.com")).to be false
      expect(EmailBlacklist.is_banned?("a@b@spam.example.com")).to be false
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

    context "with MX records" do
      before { Cache.delete(EmailBlacklist::BANNED_CACHE_KEY) }
      after  { Cache.delete(EmailBlacklist::BANNED_CACHE_KEY) }

      def stub_mx(domain, records)
        allow(EmailBlacklist).to receive(:get_mx_records).with(domain).and_return(records)
      end

      it "skips the MX lookup when the email domain already matches" do
        create(:email_blacklist, domain: "spam.example.com")
        allow(EmailBlacklist).to receive(:get_mx_records).and_return([])

        expect(EmailBlacklist.is_banned?("user@mx.spam.example.com")).to be true
        expect(EmailBlacklist).not_to have_received(:get_mx_records)
      end

      it "skips the MX lookup when the blacklist is empty" do
        allow(EmailBlacklist).to receive(:get_mx_records).and_return([])

        expect(EmailBlacklist.is_banned?("user@safe.org")).to be false
        expect(EmailBlacklist).not_to have_received(:get_mx_records)
      end

      it "falls back to the MX lookup when the email domain does not match" do
        create(:email_blacklist, domain: "spam.example.com")
        stub_mx("safe.org", [])

        expect(EmailBlacklist.is_banned?("user@safe.org")).to be false
        expect(EmailBlacklist).to have_received(:get_mx_records).with("safe.org").once
      end

      it "returns true when an MX host belongs to a blacklisted domain" do
        create(:email_blacklist, domain: "spam.example.com")
        stub_mx("safe.org", ["mx1.spam.example.com"])

        expect(EmailBlacklist.is_banned?("user@safe.org")).to be true
      end

      it "returns false when no MX host matches" do
        create(:email_blacklist, domain: "spam.example.com")
        stub_mx("safe.org", ["mx1.safe.org"])

        expect(EmailBlacklist.is_banned?("user@safe.org")).to be false
      end

      it "does not match an MX host that only shares trailing characters" do
        create(:email_blacklist, domain: "tmail.com")
        stub_mx("safe.org", ["mx.hotmail.com"])

        expect(EmailBlacklist.is_banned?("user@safe.org")).to be false
      end
    end
  end
end
