# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      SearchTrendHourly .search                              #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendHourly do
  include_context "as admin"

  let(:base_hour) { Time.utc(2026, 1, 15, 10, 0, 0) }

  let!(:fox_record)  { create(:search_trend_hourly, tag: "fox",  hour: base_hour) }
  let!(:wolf_record) { create(:search_trend_hourly, tag: "wolf", hour: base_hour) }
  let!(:fox2)        { create(:search_trend_hourly, tag: "fox_species", hour: base_hour) }

  # -------------------------------------------------------------------------
  # name_matches param
  # -------------------------------------------------------------------------
  describe "name_matches param" do
    it "returns records whose tag matches the exact pattern" do
      result = SearchTrendHourly.search(name_matches: "fox")
      expect(result).to include(fox_record)
      expect(result).not_to include(wolf_record)
    end

    it "supports trailing wildcard (*)" do
      result = SearchTrendHourly.search(name_matches: "fox*")
      expect(result).to include(fox_record, fox2)
      expect(result).not_to include(wolf_record)
    end

    it "is case-insensitive" do
      result = SearchTrendHourly.search(name_matches: "FOX")
      expect(result).to include(fox_record)
    end

    it "returns all records when params is empty" do
      result = SearchTrendHourly.search({})
      expect(result).to include(fox_record, wolf_record, fox2)
    end
  end
end
