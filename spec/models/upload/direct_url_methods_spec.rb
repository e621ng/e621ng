# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Upload::DirectURLMethods                              #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  describe "DirectURLMethods" do
    # build without direct_url so we can assign it manually below
    let(:upload) { build(:upload) }

    # -------------------------------------------------------------------------
    # #direct_url= (setter)
    # -------------------------------------------------------------------------
    describe "#direct_url=" do
      it "normalizes the string to Unicode NFC form" do
        # é as NFD: e + combining acute accent (U+0301)
        nfd = "e\u0301"
        upload.direct_url = nfd
        expect(upload.direct_url).to eq(nfd.unicode_normalize(:nfc))
      end

      it "percent-encodes non-ASCII characters in HTTP URLs" do
        url_with_unicode = "https://example.com/path/\u5e97\u8217"
        upload.direct_url = url_with_unicode
        # The stored value should be ASCII-safe (percent-encoded)
        expect(upload.direct_url).to match(%r{\Ahttps://example\.com/path/})
        expect(upload.direct_url).not_to include("\u5e97")
      end

      it "does not percent-encode a non-HTTP string" do
        plain = "local_filename_\u00e9.png"
        upload.direct_url = plain
        # NFC normalization happens, but no percent-encoding
        expect(upload.direct_url).to eq(plain.unicode_normalize(:nfc))
      end
    end

    # -------------------------------------------------------------------------
    # #direct_url_parsed
    # -------------------------------------------------------------------------
    describe "#direct_url_parsed" do
      it "returns nil when direct_url is nil" do
        upload.direct_url = nil
        expect(upload.direct_url_parsed).to be_nil
      end

      it "returns nil when direct_url is not an HTTP or HTTPS URL" do
        upload.direct_url = "ftp://example.com/file.png"
        expect(upload.direct_url_parsed).to be_nil
      end

      it "returns nil for a plain filename" do
        upload.direct_url = "image.png"
        expect(upload.direct_url_parsed).to be_nil
      end

      it "returns an Addressable::URI for an HTTP URL" do
        upload.direct_url = "http://example.com/image.jpg"
        expect(upload.direct_url_parsed).to be_a(Addressable::URI)
      end

      it "returns an Addressable::URI for an HTTPS URL" do
        upload.direct_url = "https://example.com/image.jpg"
        expect(upload.direct_url_parsed).to be_a(Addressable::URI)
      end
    end
  end
end
