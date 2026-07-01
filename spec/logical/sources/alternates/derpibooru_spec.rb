# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Derpibooru                           #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Derpibooru do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches derpibooru.org" do
      expect(described_class.new("https://derpibooru.org/images/12345").match?).to be true
    end

    it "matches derpicdn.net" do
      expect(described_class.new("https://derpicdn.net/img/view/2021/1/1/12345.jpg").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// derpibooru.org URLs to https://" do
      expect(described_class.new("http://derpibooru.org/images/12345").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — derpibooru.org /images/ query stripping
  # -------------------------------------------------------------------------
  describe "#original_url — derpibooru.org /images/ query stripping" do
    it "strips query params from a derpibooru.org /images/ URL" do
      expect(transform("https://derpibooru.org/images/12345?q=safe")).to eq("https://derpibooru.org/images/12345")
    end

    it "strips multiple query params from a derpibooru.org /images/ URL" do
      expect(transform("https://derpibooru.org/images/12345?q=safe&sf=score&sd=desc")).to eq("https://derpibooru.org/images/12345")
    end

    it "passes through a derpibooru.org /images/ URL with no query unchanged" do
      url = "https://derpibooru.org/images/12345"
      expect(transform(url)).to eq(url)
    end

    it "does not strip query from non-/images/ derpibooru.org URLs" do
      url = "https://derpibooru.org/search?q=safe"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — derpicdn.net download → view path
  # -------------------------------------------------------------------------
  describe "#original_url — derpicdn.net download to view path" do
    it "replaces 'download' with 'view' in a derpicdn.net image path" do
      expect(transform("https://derpicdn.net/img/download/2021/1/1/12345__safe_artist-colon-foo.jpg")).to \
        eq("https://derpicdn.net/img/view/2021/1/1/12345.jpg")
    end

    it "replaces 'download' with 'view' and strips tags from filename simultaneously" do
      expect(transform("https://derpicdn.net/img/download/2021/6/15/2610308__safe_artist.png")).to \
        eq("https://derpicdn.net/img/view/2021/6/15/2610308.png")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — derpicdn.net filename tag stripping
  # -------------------------------------------------------------------------
  describe "#original_url — derpicdn.net filename tag stripping" do
    it "strips tags from filename in a view path (12345__tags.jpg → 12345.jpg)" do
      expect(transform("https://derpicdn.net/img/view/2021/1/1/12345__safe_artist-colon-foo_bar.jpg")).to \
        eq("https://derpicdn.net/img/view/2021/1/1/12345.jpg")
    end

    it "passes through an already-clean filename unchanged" do
      url = "https://derpicdn.net/img/view/2021/1/1/12345.jpg"
      expect(transform(url)).to eq(url)
    end

    it "preserves the file extension after tag stripping" do
      expect(transform("https://derpicdn.net/img/view/2021/1/1/12345__tag.png")).to \
        eq("https://derpicdn.net/img/view/2021/1/1/12345.png")
    end

    it "does not alter derpicdn.net URLs that do not contain /img/ in the path" do
      url = "https://derpicdn.net/static/images/favicon.ico"
      expect(transform(url)).to eq(url)
    end
  end
end
