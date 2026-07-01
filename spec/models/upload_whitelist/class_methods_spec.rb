# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     UploadWhitelist Class Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe UploadWhitelist do
  before do
    CurrentUser.user    = create(:user)
    CurrentUser.ip_addr = "127.0.0.1"
    # Default: whitelist bypass is off so tests exercise the matching logic.
    allow(Danbooru.config.custom_configuration).to receive(:bypass_upload_whitelist?).and_return(false)
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  describe ".is_whitelisted?" do
    # -------------------------------------------------------------------------
    # invalid / malformed input
    # -------------------------------------------------------------------------
    describe "invalid input" do
      it "returns [false, 'invalid url'] for nil" do
        expect(UploadWhitelist.is_whitelisted?(nil)).to eq([false, "invalid url"])
      end

      it "returns [false, 'invalid url'] for a blank string" do
        expect(UploadWhitelist.is_whitelisted?("")).to eq([false, "invalid url"])
      end
    end

    # -------------------------------------------------------------------------
    # embedded credentials
    # -------------------------------------------------------------------------
    describe "URLs with embedded credentials" do
      it "returns [false, 'URLs with embedded credentials are not allowed'] for URLs with userinfo" do
        expect(UploadWhitelist.is_whitelisted?("http://user:pass@example.com/image.jpg")).to eq(
          [false, "URLs with embedded credentials are not allowed"],
        )
      end
    end

    # -------------------------------------------------------------------------
    # bypass
    # -------------------------------------------------------------------------
    describe "bypass_upload_whitelist?" do
      it "returns [true, 'bypassed'] when the config bypasses the whitelist" do
        allow(Danbooru.config.custom_configuration).to receive(:bypass_upload_whitelist?).and_return(true)
        expect(UploadWhitelist.is_whitelisted?("http://anywhere.example.com/file.jpg")).to eq([true, "bypassed"])
      end
    end

    # -------------------------------------------------------------------------
    # domain not in whitelist
    # -------------------------------------------------------------------------
    describe "domain not in whitelist" do
      it "returns [false, '<host> not in whitelist'] when no entry matches the domain" do
        create(:upload_whitelist, domain: "allowed\\.com", path: "\\/.+")
        result = UploadWhitelist.is_whitelisted?("http://notlisted.com/image.jpg")
        expect(result).to eq([false, "notlisted.com not in whitelist"])
      end
    end

    # -------------------------------------------------------------------------
    # domain matches, path does not
    # -------------------------------------------------------------------------
    describe "domain matches but path does not" do
      it "returns [false, '... is in whitelist, but path ... is not allowed.']" do
        create(:upload_whitelist, domain: "example\\.com", path: "\\/images\\/.+")
        result = UploadWhitelist.is_whitelisted?("http://example.com/files/doc.pdf")
        expect(result[0]).to be(false)
        expect(result[1]).to include("example.com is in whitelist")
        expect(result[1]).to include("/files/doc.pdf")
      end
    end

    # -------------------------------------------------------------------------
    # domain + path match
    # -------------------------------------------------------------------------
    describe "domain and path both match" do
      it "returns [true, reason] when the entry is allowed" do
        create(:upload_whitelist, domain: "example\\.com", path: "\\/.+", allowed: true, reason: "trusted host")
        expect(UploadWhitelist.is_whitelisted?("http://example.com/image.jpg")).to eq([true, "trusted host"])
      end

      it "returns [false, reason] when the entry is blocked" do
        create(:blocked_upload_whitelist, domain: "blocked\\.com", path: "\\/.+", reason: "spam site")
        expect(UploadWhitelist.is_whitelisted?("http://blocked.com/image.jpg")).to eq([false, "spam site"])
      end
    end

    # -------------------------------------------------------------------------
    # cache behaviour
    # -------------------------------------------------------------------------
    describe "cache behaviour" do
      it "reflects updated entries after the cache is cleared" do
        entry = create(:upload_whitelist, domain: "example\\.com", path: "\\/.+", allowed: true, reason: "original")

        # Warm the cache.
        UploadWhitelist.is_whitelisted?("http://example.com/image.jpg")

        # Update the entry — after_save clears the cache.
        entry.update!(reason: "updated reason")

        result = UploadWhitelist.is_whitelisted?("http://example.com/image.jpg")
        expect(result).to eq([true, "updated reason"])
      end
    end
  end
end
