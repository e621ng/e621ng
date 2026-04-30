# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Artist Search & Scopes                             #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  before { skip "Artist model not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:artist_urls_path) }

  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # Shared fixtures used across multiple groups.
  let!(:artist_alpha)   { make_artist(name: "search_alpha",   group_name: "gamma_group",  other_names: %w[alpha_alias shared_alias]) }
  let!(:artist_beta)    { make_artist(name: "search_beta",    group_name: "",             other_names: %w[beta_alias shared_alias]) }
  let!(:artist_gamma)   { make_artist(name: "search_gamma",   group_name: "gamma_group",  other_names: []) }
  let!(:artist_linked)  { make_artist(name: "search_linked") }

  # -------------------------------------------------------------------------
  # name param
  # -------------------------------------------------------------------------
  describe "name param" do
    it "returns an artist matching the exact name" do
      result = Artist.search(name: "search_alpha")
      expect(result).to include(artist_alpha)
      expect(result).not_to include(artist_beta)
    end

    it "supports a trailing wildcard" do
      result = Artist.search(name: "search_*")
      expect(result).to include(artist_alpha, artist_beta, artist_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # group_name param
  # -------------------------------------------------------------------------
  describe "group_name param" do
    it "filters by group_name" do
      result = Artist.search(group_name: "gamma_group")
      expect(result).to include(artist_alpha, artist_gamma)
      expect(result).not_to include(artist_beta)
    end

    it "supports wildcard matching" do
      result = Artist.search(group_name: "gamma_*")
      expect(result).to include(artist_alpha, artist_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # any_other_name_like param
  # -------------------------------------------------------------------------
  describe "any_other_name_like param" do
    it "returns artists whose other_names contains a matching entry" do
      result = Artist.search(any_other_name_like: "alpha_alias")
      expect(result).to include(artist_alpha)
      expect(result).not_to include(artist_beta)
    end

    it "supports wildcard patterns" do
      result = Artist.search(any_other_name_like: "shared_*")
      expect(result).to include(artist_alpha, artist_beta)
    end

    it "returns no results when no other_name matches" do
      expect(Artist.search(any_other_name_like: "nonexistent")).not_to include(artist_alpha, artist_beta)
    end
  end

  # -------------------------------------------------------------------------
  # any_other_name_matches param (regex)
  # -------------------------------------------------------------------------
  describe "any_other_name_matches param" do
    it "returns artists whose other_names matches the regex" do
      result = Artist.search(any_other_name_matches: "^alpha_")
      expect(result).to include(artist_alpha)
      expect(result).not_to include(artist_beta)
    end

    it "matches multiple artists when the regex is broad" do
      result = Artist.search(any_other_name_matches: "_alias$")
      expect(result).to include(artist_alpha, artist_beta)
    end
  end

  # -------------------------------------------------------------------------
  # any_name_matches param (name + other_names + group_name)
  # -------------------------------------------------------------------------
  describe "any_name_matches param" do
    it "matches by primary name" do
      result = Artist.search(any_name_matches: "search_alpha")
      expect(result).to include(artist_alpha)
    end

    it "matches by other_name" do
      result = Artist.search(any_name_matches: "beta_alias")
      expect(result).to include(artist_beta)
    end

    it "matches by group_name" do
      result = Artist.search(any_name_matches: "gamma_group")
      expect(result).to include(artist_alpha, artist_gamma)
    end

    it "wraps the query in wildcards when no wildcard is present" do
      result = Artist.search(any_name_matches: "search")
      expect(result).to include(artist_alpha, artist_beta, artist_gamma)
    end
  end

  # -------------------------------------------------------------------------
  # any_name_or_url_matches param — non-URL triggers any_name_matches
  # -------------------------------------------------------------------------
  describe "any_name_or_url_matches param" do
    it "delegates to any_name_matches for non-URL queries" do
      result = Artist.search(any_name_or_url_matches: "search_alpha")
      expect(result).to include(artist_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # url_matches param — non-HTTP string (delegates to ArtistUrl.search)
  # -------------------------------------------------------------------------
  describe "url_matches param — non-HTTP string" do
    it "returns artists whose URL contains the substring" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://furaffinity.net/user/url_search_test/")
      result = Artist.search(url_matches: "furaffinity")
      expect(result).to include(artist)
    end

    it "does not return artists whose URLs do not match" do
      no_match = make_artist
      create(:artist_url, artist: no_match, url: "http://deviantart.com/user/da_only/")
      result = Artist.search(url_matches: "furaffinity")
      expect(result).not_to include(no_match)
    end
  end

  # -------------------------------------------------------------------------
  # url_matches param — full HTTP URL (find_artists path)
  # -------------------------------------------------------------------------
  describe "url_matches param — full HTTP URL" do
    it "returns the artist whose normalized_url starts with the given URL" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://example.com/user/find_me/")
      result = Artist.search(url_matches: "http://example.com/user/find_me/")
      expect(result).to include(artist)
    end

    it "walks up the URL path and finds an artist stored at a parent directory" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://example.com/user/walk_up/")
      # The stored URL is at the parent directory; querying a deeper subpage still finds the artist
      result = Artist.search(url_matches: "http://example.com/user/walk_up/some_subpage/")
      expect(result).to include(artist)
    end

    it "stops traversal at a blacklisted domain and does not return unrelated artists" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://twitter.com/blacklist_stop_test/")
      # Querying a different twitter user should not walk up to the domain root and match this artist
      result = Artist.search(url_matches: "http://twitter.com/different_user/")
      expect(result).not_to include(artist)
    end
  end

  # -------------------------------------------------------------------------
  # any_name_or_url_matches param — HTTP URL delegates to url_matches
  # -------------------------------------------------------------------------
  describe "any_name_or_url_matches param — full HTTP URL" do
    it "routes to find_artists when the query is an http URL" do
      artist = make_artist
      create(:artist_url, artist: artist, url: "http://example.com/user/name_or_url/")
      result = Artist.search(any_name_or_url_matches: "http://example.com/user/name_or_url/")
      expect(result).to include(artist)
    end
  end

  # -------------------------------------------------------------------------
  # creator param
  # -------------------------------------------------------------------------
  describe "creator param" do
    it "filters by creator name" do
      result = Artist.search(creator_name: CurrentUser.user.name)
      expect(result).to include(artist_alpha, artist_beta)
    end

    it "returns no results for an unknown creator name" do
      result = Artist.search(creator_name: "nobody_at_all")
      expect(result).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # linked_user param
  # -------------------------------------------------------------------------
  describe "linked_user / is_linked param" do
    before do
      linked_user = create(:user)
      artist_linked.update_columns(linked_user_id: linked_user.id)
    end

    it "returns only linked artists when is_linked is truthy" do
      result = Artist.search(is_linked: "true")
      expect(result).to include(artist_linked)
      expect(result).not_to include(artist_alpha)
    end

    it "excludes linked artists when is_linked is falsy" do
      result = Artist.search(is_linked: "false")
      expect(result).to include(artist_alpha, artist_beta, artist_gamma)
      expect(result).not_to include(artist_linked)
    end
  end

  # -------------------------------------------------------------------------
  # has_tag param
  # -------------------------------------------------------------------------
  describe "has_tag param" do
    it "returns artists whose tag has post_count > 0 when has_tag is truthy" do
      Tag.find_by(name: artist_alpha.name).update_columns(post_count: 5)

      result = Artist.search(has_tag: "true")
      expect(result).to include(artist_alpha)
      expect(result).not_to include(artist_beta)
    end

    it "returns artists without a tag or with post_count <= 0 when has_tag is falsy" do
      Tag.find_by(name: artist_alpha.name).update_columns(post_count: 5)

      result = Artist.search(has_tag: "false")
      expect(result).not_to include(artist_alpha)
      expect(result).to include(artist_beta)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by name alphabetically" do
      ids = Artist.search(name: "search_*", order: "name").ids
      names = Artist.where(id: ids).order(Arel.sql("name")).ids
      expect(ids).to eq(names)
    end

    it "orders by updated_at descending" do
      artist_alpha.update_columns(updated_at: 2.hours.ago)
      artist_beta.update_columns(updated_at: 1.hour.ago)

      ids = Artist.search(name: "search_*", order: "updated_at").ids
      expect(ids.index(artist_beta.id)).to be < ids.index(artist_alpha.id)
    end

    it "orders by post_count descending when order is post_count" do
      Tag.find_by(name: artist_alpha.name).update_columns(post_count: 10)
      Tag.find_by(name: artist_beta.name).update_columns(post_count: 1)

      # pluck avoids Rails' includes GROUP BY deduplication that breaks PG ORDER BY
      ids = Artist.search(order: "post_count").pluck(:id)
      expect(ids.index(artist_alpha.id)).to be < ids.index(artist_beta.id)
    end
  end
end
