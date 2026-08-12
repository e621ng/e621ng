# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Tumblr                               #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Tumblr do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches tumblr.com" do
      expect(described_class.new("https://www.tumblr.com/unsafescapewolf/785066139893022720/raoul-in-boxers-kofi-underwear-doodles-2025").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// tumblr.com URLs to https://" do
      expect(described_class.new("http://www.tumblr.com/unsafescapewolf/785066139893022720/raoul-in-boxers-kofi-underwear-doodles-2025").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — remove source
  # -------------------------------------------------------------------------
  describe "#original_url — remove source" do
    it "removes ?source=share from the end of a URL." do
      expect(transform("https://www.tumblr.com/unsafescapewolf/785066139893022720/raoul-in-boxers-kofi-underwear-doodles-2025?source=share")).to \
        eq("https://www.tumblr.com/unsafescapewolf/785066139893022720/raoul-in-boxers-kofi-underwear-doodles-2025")
    end

    it "does not alter non-source-containing URLs" do
      url = "https://www.tumblr.com/unsafescapewolf/785066139893022720/raoul-in-boxers-kofi-underwear-doodles-2025"
      expect(transform(url)).to eq(url)
    end
  end
end
