# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Facebook                             #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Facebook do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches facebook.com" do
      expect(described_class.new("https://www.facebook.com/photo.php?fbid=123456789").match?).to be true
    end

    it "matches m.facebook.com" do
      expect(described_class.new("https://m.facebook.com/photo.php?fbid=123456789").match?).to be true
    end

    it "matches web.facebook.com" do
      expect(described_class.new("https://web.facebook.com/photo.php?fbid=123456789").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// facebook.com URLs to https://" do
      expect(described_class.new("http://www.facebook.com/photo.php?fbid=123456789").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — alternate subdomains to desktop
  # -------------------------------------------------------------------------
  describe "converts alternate subdomains to desktop" do
    it "converts m.facebook.com to www.facebook.com" do
      expect(transform("https://m.facebook.com/photo.php?fbid=3058563794264742&id=896121230509020&set=a.291602508185194&source=43")).to \
        eq("https://www.facebook.com/photo.php?fbid=3058563794264742")
    end

    it "converts web.facebook.com to www.facebook.com" do
      expect(transform("https://web.facebook.com/photo.php?fbid=3058563794264742")).to \
        eq("https://www.facebook.com/photo.php?fbid=3058563794264742")
    end

    it "does not alter already-desktop URLs" do
      url = "https://www.facebook.com/photo.php?fbid=3058563794264742"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — photo.php query strip
  # -------------------------------------------------------------------------
  describe "#original_url — photo.php query strip" do
    it "strips all params except fbid from /photo.php" do
      expect(transform("https://www.facebook.com/photo.php?fbid=3058563794264742&id=896121230509020&set=a.291602508185194&source=43")).to \
        eq("https://www.facebook.com/photo.php?fbid=3058563794264742")
    end

    it "rewrites /photo to /photo.php and strips tracking params" do
      expect(transform("https://www.facebook.com/photo?fbid=3058563794264742&set=a.291602508185194&source=43")).to \
        eq("https://www.facebook.com/photo.php?fbid=3058563794264742")
    end

    it "rewrites /photo/ to /photo.php and strips tracking params" do
      expect(transform("https://www.facebook.com/photo/?fbid=3058563794264742&set=a.291602508185194")).to \
        eq("https://www.facebook.com/photo.php?fbid=3058563794264742")
    end

    it "does not alter photo.php URLs that have no fbid" do
      url = "https://www.facebook.com/photo.php?set=a.291602508185194"
      expect(transform(url)).to eq(url)
    end

    it "does not alter non-photo.php URLs" do
      url = "https://www.facebook.com/artist/posts/123456789"
      expect(transform(url)).to eq(url)
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — story.php query strip
  # -------------------------------------------------------------------------
  describe "#original_url — story.php query strip" do
    it "strips tracking params from pfbid story.php URLs, keeping story_fbid and id" do
      expect(transform("https://m.facebook.com/story.php?story_fbid=pfbid021Xh5bfEy1wjHgqKCcNpyn5f6pfFyp3wNW6ziaPUrP999cLUanJgnf95XfuwLCAGAl&id=100070332554180&mibextid=NOb6eG&_rdr")).to \
        eq("https://www.facebook.com/story.php?id=100070332554180&story_fbid=pfbid021Xh5bfEy1wjHgqKCcNpyn5f6pfFyp3wNW6ziaPUrP999cLUanJgnf95XfuwLCAGAl")
    end

    it "canonicalizes fbid story.php URLs to sorted param order" do
      expect(transform("https://www.facebook.com/story.php?story_fbid=3192370837660222&id=1515778811986108")).to \
        eq("https://www.facebook.com/story.php?id=1515778811986108&story_fbid=3192370837660222")
    end

    it "does not alter story.php URLs without a story_fbid param" do
      url = "https://www.facebook.com/story.php?id=100070332554180"
      expect(transform(url)).to eq(url)
    end
  end
end
