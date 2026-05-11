# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    Sources::Alternates::Youtube                             #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Youtube do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches youtube.com" do
      expect(described_class.new("https://www.youtube.com/watch?v=dQw4w9WgXcQ").match?).to be true
    end

    it "matches youtu.be" do
      expect(described_class.new("https://youtu.be/dQw4w9WgXcQ").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// youtube.com URLs to https://" do
      expect(described_class.new("http://www.youtube.com/watch?v=dQw4w9WgXcQ").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — youtu.be short URL expansion
  # -------------------------------------------------------------------------
  describe "#original_url — youtu.be short URL expansion" do
    it "converts youtu.be/ID to www.youtube.com/watch?v=ID" do
      expect(transform("https://youtu.be/dQw4w9WgXcQ")).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    it "drops extra params after youtu.be expansion (only v is kept on /watch)" do
      expect(transform("https://youtu.be/dQw4w9WgXcQ?si=abc123&t=30")).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — /shorts/ URL conversion
  # -------------------------------------------------------------------------
  describe "#original_url — /shorts/ URL conversion" do
    it "converts /shorts/ID to /watch?v=ID" do
      expect(transform("https://www.youtube.com/shorts/dQw4w9WgXcQ")).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    it "drops extra params from a shorts URL" do
      expect(transform("https://www.youtube.com/shorts/dQw4w9WgXcQ?si=abc123&feature=share")).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — host normalization to www.youtube.com
  # -------------------------------------------------------------------------
  describe "#original_url — host normalization to www.youtube.com" do
    it "normalizes m.youtube.com to www.youtube.com" do
      expect(transform("https://m.youtube.com/watch?v=dQw4w9WgXcQ")).to eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    it "keeps www.youtube.com unchanged" do
      url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — /watch URL tracking param removal
  # -------------------------------------------------------------------------
  describe "#original_url — /watch URL tracking param removal" do
    it "keeps only the v param on /watch URLs" do
      expect(transform("https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLabc&index=2&t=30&si=xyz")).to \
        eq("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    it "passes through /watch?v= with no extra params unchanged" do
      url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — non-/watch URL tracking param removal
  # -------------------------------------------------------------------------
  describe "#original_url — non-/watch URL tracking param removal" do
    it "removes the si param from a channel URL" do
      expect(transform("https://www.youtube.com/channel/UCxxxxxxxx?si=abc123")).to eq("https://www.youtube.com/channel/UCxxxxxxxx")
    end

    it "removes list and index params from a channel URL" do
      expect(transform("https://www.youtube.com/channel/UCxxxxxxxx?list=PLabc&index=2")).to eq("https://www.youtube.com/channel/UCxxxxxxxx")
    end

    it "removes utm_* params from a channel URL" do
      expect(transform("https://www.youtube.com/channel/UCxxxxxxxx?utm_source=share")).to eq("https://www.youtube.com/channel/UCxxxxxxxx")
    end

    it "removes the t (timestamp) param from a channel URL" do
      expect(transform("https://www.youtube.com/channel/UCxxxxxxxx?t=120")).to eq("https://www.youtube.com/channel/UCxxxxxxxx")
    end

    it "removes the feature param from a channel URL" do
      expect(transform("https://www.youtube.com/channel/UCxxxxxxxx?feature=shared")).to eq("https://www.youtube.com/channel/UCxxxxxxxx")
    end

    it "preserves non-tracking params on non-/watch URLs" do
      url = "https://www.youtube.com/results?search_query=cats"
      expect(transform(url)).to eq(url)
    end
  end
end
