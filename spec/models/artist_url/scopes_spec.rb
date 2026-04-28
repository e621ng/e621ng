# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ArtistUrl Scopes                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistUrl do
  include_context "as admin"

  def make_url(overrides = {})
    create(:artist_url, **overrides)
  end

  # -------------------------------------------------------------------------
  # .url_matches
  # -------------------------------------------------------------------------
  describe ".url_matches" do
    let!(:fa_url)  { make_url(url: "http://furaffinity.net/user/artist_one/") }
    let!(:da_url)  { make_url(url: "http://deviantart.com/artist_two/") }

    it "returns all records when url is blank" do
      expect(ArtistUrl.url_matches("")).to include(fa_url, da_url)
    end

    it "matches by substring when no wildcard is given" do
      result = ArtistUrl.url_matches("furaffinity")
      expect(result).to include(fa_url)
      expect(result).not_to include(da_url)
    end

    it "respects an explicit wildcard in the pattern" do
      result = ArtistUrl.url_matches("*artist_*")
      expect(result).to include(fa_url, da_url)
    end

    it "is case-insensitive" do
      result = ArtistUrl.url_matches("FURAFFINITY")
      expect(result).to include(fa_url)
    end
  end

  # -------------------------------------------------------------------------
  # .normalized_url_matches
  # -------------------------------------------------------------------------
  describe ".normalized_url_matches" do
    # normalized_url has https:// converted to http:// and a trailing slash added
    let!(:pixiv_url) { make_url(url: "https://www.pixiv.net/en/users/12345/") }
    let!(:twitter_url) { make_url(url: "http://twitter.com/artist_three/") }

    it "returns all records when url is blank" do
      expect(ArtistUrl.normalized_url_matches("")).to include(pixiv_url, twitter_url)
    end

    it "matches by substring when no wildcard is given" do
      result = ArtistUrl.normalized_url_matches("pixiv")
      expect(result).to include(pixiv_url)
      expect(result).not_to include(twitter_url)
    end

    it "respects an explicit wildcard in the pattern" do
      result = ArtistUrl.normalized_url_matches("*artist_*")
      expect(result).to include(twitter_url)
    end

    it "is case-insensitive" do
      result = ArtistUrl.normalized_url_matches("TWITTER")
      expect(result).to include(twitter_url)
    end
  end
end
