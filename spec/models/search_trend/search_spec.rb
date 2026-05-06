# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          SearchTrend .search                                #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrend do
  include_context "as admin"

  let(:fixed_day) { Date.new(2026, 1, 15) }

  let!(:fox_record)     { create(:search_trend, tag: "fox",         day: fixed_day) }
  let!(:wolf_record)    { create(:search_trend, tag: "wolf",        day: fixed_day) }
  let!(:fox_alt_record) { create(:search_trend, tag: "fox_species", day: fixed_day) }

  # -------------------------------------------------------------------------
  # name_matches param
  # -------------------------------------------------------------------------
  describe "name_matches param" do
    it "returns records whose tag matches the exact pattern" do
      result = SearchTrend.search(name_matches: "fox")
      expect(result).to include(fox_record)
      expect(result).not_to include(wolf_record)
    end

    it "supports trailing wildcard (*)" do
      result = SearchTrend.search(name_matches: "fox*")
      expect(result).to include(fox_record, fox_alt_record)
      expect(result).not_to include(wolf_record)
    end

    it "is case-insensitive" do
      result = SearchTrend.search(name_matches: "FOX")
      expect(result).to include(fox_record)
    end

    it "returns all records when params is empty" do
      result = SearchTrend.search({})
      expect(result).to include(fox_record, wolf_record, fox_alt_record)
    end
  end
end
