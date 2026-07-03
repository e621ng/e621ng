# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Tapas                                #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Tapas do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches tapas.io" do
      expect(described_class.new("https://tapas.io/episode/189498").match?).to be true
    end

    it "matches m.tapas.io" do
      expect(described_class.new("https://m.tapas.io/episode/189498").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// tapas.io URLs to https://" do
      expect(described_class.new("http://tapas.io/episode/189498").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — mobile to desktop
  # -------------------------------------------------------------------------
  describe "#original_url — mobile to desktop" do
    it "converts m.tapas.io to tapas.io" do
      expect(transform("https://m.tapas.io/episode/189498")).to eq("https://tapas.io/episode/189498")
    end

    it "does not alter already-desktop URLs" do
      url = "https://tapas.io/episode/189498"
      expect(transform(url)).to eq(url)
    end
  end
end
