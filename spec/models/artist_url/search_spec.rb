# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ArtistUrl Search                                    #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistUrl do
  include_context "as admin"

  def make_url(overrides = {})
    create(:artist_url, **overrides)
  end

  let!(:artist_one) { create(:artist) }
  let!(:artist_two) { create(:artist) }

  let!(:url_one)    { make_url(artist: artist_one, url: "http://furaffinity.net/user/one/",  is_active: true) }
  let!(:url_two)    { make_url(artist: artist_two, url: "http://deviantart.com/user/two/",   is_active: false) }
  let!(:url_three)  { make_url(artist: artist_one, url: "http://twitter.com/user/three/",    is_active: true) }

  # -------------------------------------------------------------------------
  # artist_id param
  # -------------------------------------------------------------------------
  describe "artist_id param" do
    it "returns urls belonging to the given artist" do
      result = ArtistUrl.search(artist_id: artist_one.id.to_s)
      expect(result).to include(url_one, url_three)
      expect(result).not_to include(url_two)
    end
  end

  # -------------------------------------------------------------------------
  # is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    it "returns only active urls when true" do
      result = ArtistUrl.search(is_active: "true")
      expect(result).to include(url_one, url_three)
      expect(result).not_to include(url_two)
    end

    it "returns only inactive urls when false" do
      result = ArtistUrl.search(is_active: "false")
      expect(result).to include(url_two)
      expect(result).not_to include(url_one, url_three)
    end
  end

  # -------------------------------------------------------------------------
  # url param
  # -------------------------------------------------------------------------
  describe "url param" do
    it "filters by exact url" do
      result = ArtistUrl.search(url: "http://furaffinity.net/user/one/")
      expect(result).to include(url_one)
      expect(result).not_to include(url_two)
    end
  end

  # -------------------------------------------------------------------------
  # normalized_url param
  # -------------------------------------------------------------------------
  describe "normalized_url param" do
    it "filters by exact normalized_url" do
      result = ArtistUrl.search(normalized_url: url_one.normalized_url)
      expect(result).to include(url_one)
      expect(result).not_to include(url_two)
    end
  end

  # -------------------------------------------------------------------------
  # artist_name param
  # -------------------------------------------------------------------------
  describe "artist_name param" do
    it "returns urls whose artist has the given name" do
      result = ArtistUrl.search(artist_name: artist_one.name)
      expect(result).to include(url_one, url_three)
      expect(result).not_to include(url_two)
    end

    it "returns no results when no artist matches the name" do
      result = ArtistUrl.search(artist_name: "nonexistent_artist_name")
      expect(result).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # url_matches param (delegates to .url_matches scope)
  # -------------------------------------------------------------------------
  describe "url_matches param" do
    it "returns urls matching the substring pattern" do
      result = ArtistUrl.search(url_matches: "furaffinity")
      expect(result).to include(url_one)
      expect(result).not_to include(url_two, url_three)
    end
  end

  # -------------------------------------------------------------------------
  # normalized_url_matches param (delegates to .normalized_url_matches scope)
  # -------------------------------------------------------------------------
  describe "normalized_url_matches param" do
    it "returns urls whose normalized_url matches the substring pattern" do
      result = ArtistUrl.search(normalized_url_matches: "deviantart")
      expect(result).to include(url_two)
      expect(result).not_to include(url_one, url_three)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by id desc by default" do
      ids = ArtistUrl.search({}).ids
      expect(ids.index(url_three.id)).to be < ids.index(url_one.id)
    end

    it "orders by url asc when specified" do
      results = ArtistUrl.search(order: "url_asc").to_a
      urls = results.map(&:url)
      expect(urls).to eq(urls.sort)
    end

    it "orders by url desc when specified" do
      results = ArtistUrl.search(order: "url_desc").to_a
      urls = results.map(&:url)
      expect(urls).to eq(urls.sort.reverse)
    end

    it "falls back to default order for an unrecognized order string" do
      expect { ArtistUrl.search(order: "invalid_order_xyz").to_a }.not_to raise_error
    end
  end
end
