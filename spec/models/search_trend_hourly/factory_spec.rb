# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      SearchTrendHourly Factory                              #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendHourly do
  describe "factory" do
    it "produces a valid record with build" do
      record = build(:search_trend_hourly)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      record = create(:search_trend_hourly)
      expect(record).to be_persisted
    end
  end
end
