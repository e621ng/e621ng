# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ArtistUrl Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistUrl do
  include_context "as admin"

  def make_url(overrides = {})
    create(:artist_url, **overrides)
  end

  # -------------------------------------------------------------------------
  # .parse_prefix
  # -------------------------------------------------------------------------
  describe ".parse_prefix" do
    it "returns [true, url] when there is no leading dash" do
      is_active, url = ArtistUrl.parse_prefix("http://example.com/artist/")
      expect(is_active).to be true
      expect(url).to eq("http://example.com/artist/")
    end

    it "returns [false, url] when there is a leading dash" do
      is_active, url = ArtistUrl.parse_prefix("-http://example.com/artist/")
      expect(is_active).to be false
      expect(url).to eq("http://example.com/artist/")
    end

    it "strips only the leading dash and leaves the rest of the url intact" do
      _is_active, url = ArtistUrl.parse_prefix("-http://example.com/path/to/page/")
      expect(url).to eq("http://example.com/path/to/page/")
    end
  end

  # -------------------------------------------------------------------------
  # #to_s
  # -------------------------------------------------------------------------
  describe "#to_s" do
    it "returns the bare url when the record is active" do
      record = make_url(url: "http://example.com/artist/", is_active: true)
      expect(record.to_s).to eq("http://example.com/artist/")
    end

    it "prepends a dash when the record is inactive" do
      record = make_url(url: "http://example.com/artist/", is_active: false)
      expect(record.to_s).to eq("-http://example.com/artist/")
    end
  end

  # -------------------------------------------------------------------------
  # #priority
  # -------------------------------------------------------------------------
  describe "#priority" do
    it "returns a higher value for an active url than for the same inactive url" do
      active   = make_url(url: "http://furaffinity.net/user/artist/", is_active: true)
      inactive = make_url(url: "http://furaffinity.net/user/artist2/", is_active: false)
      expect(active.priority).to be > inactive.priority
    end

    it "returns a higher value for a higher-priority site (furaffinity.net > carrd.co)" do
      fa     = make_url(url: "http://furaffinity.net/user/artist/",  is_active: true)
      carrd  = make_url(url: "http://carrd.co/artist/",              is_active: true)
      expect(fa.priority).to be > carrd.priority
    end

    it "returns 0 base priority for an unknown domain" do
      record = make_url(url: "http://unknown-site-xyz.example/artist/", is_active: true)
      expect(record.priority).to eq(0)
    end

    it "assigns priority 10_000 for a url that cannot be parsed" do
      record = make_url(url: "http://example.com/ok/")
      # Unclosed IPv6 bracket reliably raises Addressable::URI::InvalidURIError
      record.url = "http:"
      expect(record.priority).to eq(10_000)
    end

    it "subtracts 1000 from priority for an inactive url with an unparseable url" do
      record = make_url(url: "http://example.com/ok/", is_active: false)
      record.url = "http:"
      expect(record.priority).to eq(10_000 - 1000)
    end
  end
end
