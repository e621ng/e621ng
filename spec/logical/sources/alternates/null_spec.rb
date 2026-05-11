# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Sources::Alternates::Null                             #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Null do
  describe "#match?" do
    it "returns false for any URL" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end

    it "returns false for nil" do
      expect(described_class.new(nil).match?).to be false
    end
  end

  describe "#original_url" do
    it "returns the URL unchanged" do
      expect(described_class.new("https://example.com/image.png").original_url).to eq("https://example.com/image.png")
    end
  end
end
