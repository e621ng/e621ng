# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Sources::Alternates::Base                             #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Base do
  # -------------------------------------------------------------------------
  # #initialize / URL parsing
  # -------------------------------------------------------------------------
  describe "#initialize" do
    it "parses a valid URL and exposes it via #url" do
      base = described_class.new("https://example.com/path")
      expect(base.url).to eq("https://example.com/path")
    end

    it "sets parsed_url to an Addressable::URI for a valid URL" do
      base = described_class.new("https://example.com/path")
      expect(base.parsed_url).to be_a(Addressable::URI)
    end

    it "sets parsed_url to nil for nil without raising" do
      expect { described_class.new(nil) }.not_to raise_error
      expect(described_class.new(nil).parsed_url).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http://weasyl.com URLs to HTTPS" do
      expect(described_class.new("http://weasyl.com/submission/12345").url).to start_with("https://")
    end

    it "upgrades http://e-hentai.org URLs to HTTPS" do
      expect(described_class.new("http://e-hentai.org/g/12345/abc/").url).to start_with("https://")
    end

    it "does not alter URLs for domains not in the secure list" do
      expect(described_class.new("http://example.com/image.jpg").url).to start_with("http://")
    end
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "returns false because Base has no domains defined" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end

    it "returns false for a nil URL" do
      expect(described_class.new(nil).match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #original_url
  # -------------------------------------------------------------------------
  describe "#original_url" do
    it "returns the URL unchanged" do
      base = described_class.new("https://example.com/image.png")
      expect(base.original_url).to eq("https://example.com/image.png")
    end

    it "returns nil when initialized with nil" do
      expect(described_class.new(nil).original_url).to be_nil
    end
  end
end
