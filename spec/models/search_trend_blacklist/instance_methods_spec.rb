# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                SearchTrendBlacklist Instance Methods                        #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendBlacklist do
  include_context "as admin"

  def make_blacklist(tag, reason: "reason")
    create(:search_trend_blacklist, tag: tag, reason: reason)
  end

  # =========================================================================
  # #purge!
  # =========================================================================
  #
  # purge! converts the blacklist entry's tag (treated as a glob pattern) to a
  # SQL LIKE pattern and deletes all matching SearchTrend rows.  It does not
  # touch SearchTrendHourly.
  # =========================================================================
  describe "#purge!" do
    let(:fixed_day) { Time.now.utc.to_date }

    it "deletes SearchTrend rows whose tag matches the exact blacklist tag" do
      create(:search_trend, tag: "fox", day: fixed_day)
      entry = make_blacklist("fox")
      entry.purge!
      expect(SearchTrend.where(tag: "fox").exists?).to be false
    end

    it "deletes SearchTrend rows matching a * glob pattern" do
      create(:search_trend, tag: "fox_tail", day: fixed_day)
      create(:search_trend, tag: "fox_ear",  day: fixed_day)
      entry = make_blacklist("fox_*")
      entry.purge!
      expect(SearchTrend.where(tag: %w[fox_tail fox_ear]).count).to eq(0)
    end

    it "does not delete SearchTrend rows that do not match the pattern" do
      control = create(:search_trend, tag: "wolf", day: fixed_day)
      entry   = make_blacklist("fox")
      entry.purge!
      expect(SearchTrend.exists?(control.id)).to be true
    end

    it "returns 0 when no SearchTrend rows match" do
      entry = make_blacklist("fox")
      expect(entry.purge!).to eq(0)
    end

    it "returns the count of deleted SearchTrend rows" do
      create(:search_trend, tag: "fox_tail", day: fixed_day)
      create(:search_trend, tag: "fox_ear",  day: fixed_day)
      entry = make_blacklist("fox_*")
      expect(entry.purge!).to eq(2)
    end

    it "does not delete SearchTrendHourly rows matching the pattern" do
      create(:search_trend_hourly, tag: "fox", hour: Time.now.utc.beginning_of_hour)
      entry = make_blacklist("fox")
      entry.purge!
      expect(SearchTrendHourly.where(tag: "fox").exists?).to be true
    end
  end
end
