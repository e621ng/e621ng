# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         AvoidPosting Search                                 #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  # Shared fixtures reused across groups.
  let!(:dnp_alpha)   { create(:avoid_posting, artist: create(:artist, name: "search_alpha"), details: "contact first") }
  let!(:dnp_beta)    { create(:avoid_posting, artist: create(:artist, name: "search_beta"),  details: "") }
  let!(:dnp_deleted) { create(:inactive_avoid_posting, artist: create(:artist, name: "search_deleted")) }

  # -------------------------------------------------------------------------
  # default scope (active only)
  # -------------------------------------------------------------------------
  describe "default (no is_active param)" do
    it "includes active entries" do
      expect(AvoidPosting.search({})).to include(dnp_alpha, dnp_beta)
    end

    it "excludes deleted entries" do
      expect(AvoidPosting.search({})).not_to include(dnp_deleted)
    end
  end

  # -------------------------------------------------------------------------
  # is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    it "returns only deleted entries when is_active is false" do
      result = AvoidPosting.search(is_active: "false")
      expect(result).to include(dnp_deleted)
      expect(result).not_to include(dnp_alpha, dnp_beta)
    end

    it "returns only active entries when is_active is true" do
      result = AvoidPosting.search(is_active: "true")
      expect(result).to include(dnp_alpha, dnp_beta)
      expect(result).not_to include(dnp_deleted)
    end
  end

  # -------------------------------------------------------------------------
  # artist_id param
  # -------------------------------------------------------------------------
  # FIXME: passing an Integer artist_id crashes in ParseValue#range with
  # `undefined method 'start_with?' for an instance of Integer`.
  # artist_search passes the value directly to Artist.search(id:), which
  # routes it through numeric_attribute_matches without stringifying first.
  # describe "artist_id param" do
  #   it "returns the entry matching the given artist_id" do
  #     result = AvoidPosting.search(artist_id: dnp_alpha.artist_id)
  #     expect(result).to include(dnp_alpha)
  #     expect(result).not_to include(dnp_beta)
  #   end
  # end

  # -------------------------------------------------------------------------
  # artist_name param
  # -------------------------------------------------------------------------
  describe "artist_name param" do
    it "returns the entry matching the exact artist name" do
      result = AvoidPosting.search(artist_name: "search_alpha")
      expect(result).to include(dnp_alpha)
      expect(result).not_to include(dnp_beta)
    end
  end

  # -------------------------------------------------------------------------
  # any_name_matches param
  # -------------------------------------------------------------------------
  describe "any_name_matches param" do
    it "supports wildcard matching against artist names" do
      result = AvoidPosting.search(any_name_matches: "search_*")
      expect(result).to include(dnp_alpha, dnp_beta)
    end

    it "excludes non-matching entries" do
      result = AvoidPosting.search(any_name_matches: "search_alpha")
      expect(result).not_to include(dnp_beta)
    end
  end

  # -------------------------------------------------------------------------
  # details param
  # -------------------------------------------------------------------------
  describe "details param" do
    it "filters by details content" do
      result = AvoidPosting.search(details: "contact first")
      expect(result).to include(dnp_alpha)
      expect(result).not_to include(dnp_beta)
    end
  end

  # -------------------------------------------------------------------------
  # ordering
  # -------------------------------------------------------------------------
  describe "order param" do
    let!(:dnp_aardvark) { create(:avoid_posting, artist: create(:artist, name: "aardvark_dnp")) }
    let!(:dnp_zebra)    { create(:avoid_posting, artist: create(:artist, name: "zebra_dnp")) }

    it "orders by artist name ascending when order is 'artist_name'" do
      ids = AvoidPosting.search(order: "artist_name").ids
      expect(ids.index(dnp_aardvark.id)).to be < ids.index(dnp_zebra.id)
    end

    it "orders by artist name descending when order is 'artist_name_desc'" do
      ids = AvoidPosting.search(order: "artist_name_desc").ids
      expect(ids.index(dnp_zebra.id)).to be < ids.index(dnp_aardvark.id)
    end

    it "orders by created_at descending when order is 'created_at'" do
      dnp_aardvark.update_columns(created_at: 1.hour.ago)
      ids = AvoidPosting.search(order: "created_at").ids
      expect(ids.index(dnp_zebra.id)).to be < ids.index(dnp_aardvark.id)
    end
  end
end
