# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebpInspector do
  describe ".is_animated?" do
    it "returns true for an animated WebP" do
      expect(described_class.is_animated?(file_fixture("animated.webp").to_s)).to be true
    end

    it "returns false for a static WebP" do
      expect(described_class.is_animated?(file_fixture("sample.webp").to_s)).to be false
    end

    it "returns false for a non-WebP file" do
      expect(described_class.is_animated?(file_fixture("animated.png").to_s)).to be false
    end
  end

  describe ".duration" do
    it "sums the frame durations of an animated WebP" do
      expect(described_class.duration(file_fixture("animated.webp").to_s)).to be_within(0.001).of(2.0)
    end

    it "returns nil for a static WebP" do
      expect(described_class.duration(file_fixture("sample.webp").to_s)).to be_nil
    end

    it "returns nil for a non-WebP file" do
      expect(described_class.duration(file_fixture("animated.gif").to_s)).to be_nil
    end

    it "returns nil for a missing file" do
      expect(described_class.duration("/nonexistent/path.webp")).to be_nil
    end
  end
end
