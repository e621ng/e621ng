# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Deviantart                           #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Deviantart do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches www.deviantart.com" do
      expect(described_class.new("https://www.deviantart.com/artist/art/title-12345").match?).to be true
    end

    it "matches artist subdomain deviantart.com" do
      expect(described_class.new("https://artist.deviantart.com/art/title-12345").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// deviantart.com URLs to https://" do
      expect(described_class.new("http://artist.deviantart.com/art/Some-Title-12345678").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — subdomain → www.deviantart.com/username/
  # -------------------------------------------------------------------------
  describe "#original_url — subdomain to www path conversion" do
    it "converts artist.deviantart.com/art/... to www.deviantart.com/artist/art/..." do
      expect(transform("https://artist.deviantart.com/art/Some-Title-12345678")).to eq("https://www.deviantart.com/artist/art/Some-Title-12345678")
    end

    it "converts username.deviantart.com gallery link" do
      expect(transform("https://myusername.deviantart.com/gallery/")).to eq("https://www.deviantart.com/myusername/gallery/")
    end

    it "passes through already-canonical www.deviantart.com URLs unchanged" do
      url = "https://www.deviantart.com/artist/art/Some-Title-12345678"
      expect(transform(url)).to eq(url)
    end

    it "passes through bare deviantart.com (no subdomain) unchanged" do
      # deviantart.com is in BASE_HOSTS, so no subdomain extraction occurs
      url = "https://deviantart.com/artist/art/Some-Title-12345678"
      expect(transform(url)).to eq(url)
    end
  end
end
