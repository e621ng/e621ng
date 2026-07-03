# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Imgur                                #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Imgur do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches imgur.com" do
      expect(described_class.new("https://imgur.com/a/zZkdMts").match?).to be true
    end

    it "matches m.imgur.com" do
      expect(described_class.new("https://m.imgur.com/a/zZkdMts").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// imgur.com URLs to https://" do
      expect(described_class.new("http://imgur.com/a/zZkdMts").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — mobile to desktop
  # -------------------------------------------------------------------------
  describe "#original_url — mobile to desktop" do
    it "converts m.imgur.com to imgur.com" do
      expect(transform("https://m.imgur.com/a/zZkdMts")).to eq("https://imgur.com/a/zZkdMts")
    end

    it "does not alter already-desktop URLs" do
      url = "https://imgur.com/a/zZkdMts"
      expect(transform(url)).to eq(url)
    end
  end
end
