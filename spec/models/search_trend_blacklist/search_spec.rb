# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     SearchTrendBlacklist .search                            #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendBlacklist do
  include_context "as admin"

  let!(:fox_entry)    { create(:search_trend_blacklist, tag: "fox",         reason: "spam") }
  let!(:wolf_entry)   { create(:search_trend_blacklist, tag: "wolf",        reason: "spam") }
  let!(:fox_alt_entry) { create(:search_trend_blacklist, tag: "fox_species", reason: "other reason") }

  # -------------------------------------------------------------------------
  # tag param
  # -------------------------------------------------------------------------
  describe "tag param" do
    it "returns records whose tag matches the exact pattern" do
      result = SearchTrendBlacklist.search(tag: "fox")
      expect(result).to include(fox_entry)
      expect(result).not_to include(wolf_entry)
    end

    it "supports trailing wildcard (*)" do
      result = SearchTrendBlacklist.search(tag: "fox*")
      expect(result).to include(fox_entry, fox_alt_entry)
      expect(result).not_to include(wolf_entry)
    end

    it "is case-insensitive" do
      result = SearchTrendBlacklist.search(tag: "FOX")
      expect(result).to include(fox_entry)
    end
  end

  # -------------------------------------------------------------------------
  # reason param
  # -------------------------------------------------------------------------
  describe "reason param" do
    it "returns records whose reason matches the exact pattern" do
      result = SearchTrendBlacklist.search(reason: "other reason")
      expect(result).to include(fox_alt_entry)
      expect(result).not_to include(fox_entry, wolf_entry)
    end

    it "supports trailing wildcard (*)" do
      result = SearchTrendBlacklist.search(reason: "spam*")
      expect(result).to include(fox_entry, wolf_entry)
      expect(result).not_to include(fox_alt_entry)
    end

    it "is case-insensitive" do
      result = SearchTrendBlacklist.search(reason: "SPAM")
      expect(result).to include(fox_entry, wolf_entry)
    end
  end

  # -------------------------------------------------------------------------
  # empty params
  # -------------------------------------------------------------------------
  describe "empty params" do
    it "returns all records when params is empty" do
      result = SearchTrendBlacklist.search({})
      expect(result).to include(fox_entry, wolf_entry, fox_alt_entry)
    end
  end
end
