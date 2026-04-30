# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        SearchTrendHourly Scopes                             #
# --------------------------------------------------------------------------- #
#
# All fixtures use fixed UTC timestamps so scope boundaries are deterministic
# regardless of when the test runs.

RSpec.describe SearchTrendHourly do
  # -------------------------------------------------------------------------
  # .for_day
  # -------------------------------------------------------------------------
  describe ".for_day" do
    let!(:on_day)   { create(:search_trend_hourly, hour: Time.utc(2026, 1, 15, 10, 0, 0)) }
    let!(:next_day) { create(:search_trend_hourly, hour: Time.utc(2026, 1, 16, 1,  0, 0)) }
    let!(:prev_day) { create(:search_trend_hourly, hour: Time.utc(2026, 1, 14, 23, 0, 0)) }

    it "returns records whose hour falls within the given UTC date" do
      expect(SearchTrendHourly.for_day(Date.new(2026, 1, 15))).to include(on_day)
    end

    it "excludes records from the following day" do
      expect(SearchTrendHourly.for_day(Date.new(2026, 1, 15))).not_to include(next_day)
    end

    it "excludes records from the preceding day" do
      expect(SearchTrendHourly.for_day(Date.new(2026, 1, 15))).not_to include(prev_day)
    end
  end

  # -------------------------------------------------------------------------
  # .for_hour
  # -------------------------------------------------------------------------
  describe ".for_hour" do
    let(:target_hour) { Time.utc(2026, 1, 15, 10, 0, 0) }

    let!(:high_count) { create(:search_trend_hourly, tag: "aaa_high", hour: target_hour, count: 50) }
    let!(:low_count)  { create(:search_trend_hourly, tag: "zzz_low",  hour: target_hour, count: 5) }
    let!(:other_hour) { create(:search_trend_hourly, hour: target_hour + 1.hour) }

    it "returns records matching the given UTC hour" do
      expect(SearchTrendHourly.for_hour(target_hour)).to include(high_count, low_count)
    end

    it "excludes records from an adjacent hour" do
      expect(SearchTrendHourly.for_hour(target_hour)).not_to include(other_hour)
    end

    it "orders by count descending" do
      result = SearchTrendHourly.for_hour(target_hour).to_a
      expect(result.first).to eq(high_count)
      expect(result.last).to eq(low_count)
    end

    it "orders by tag ascending when counts are equal" do
      create(:search_trend_hourly, tag: "aaa_tied", hour: target_hour, count: 10)
      create(:search_trend_hourly, tag: "zzz_tied", hour: target_hour, count: 10)
      result = SearchTrendHourly.for_hour(target_hour).select { |r| r.count == 10 }
      expect(result.map(&:tag)).to eq(result.map(&:tag).sort)
    end
  end

  # -------------------------------------------------------------------------
  # .for_tag
  # -------------------------------------------------------------------------
  describe ".for_tag" do
    let(:base_hour) { Time.utc(2026, 1, 15, 10, 0, 0) }

    let!(:target) { create(:search_trend_hourly, tag: "fox", hour: base_hour) }
    let!(:other)  { create(:search_trend_hourly, tag: "wolf", hour: base_hour) }

    it "returns records matching the given tag" do
      expect(SearchTrendHourly.for_tag("fox")).to include(target)
    end

    it "normalizes the input by downcasing" do
      expect(SearchTrendHourly.for_tag("FOX")).to include(target)
    end

    it "normalizes the input by stripping surrounding whitespace" do
      expect(SearchTrendHourly.for_tag("  fox  ")).to include(target)
    end

    it "excludes records with a different tag" do
      expect(SearchTrendHourly.for_tag("fox")).not_to include(other)
    end
  end

  # -------------------------------------------------------------------------
  # .unprocessed
  # -------------------------------------------------------------------------
  describe ".unprocessed" do
    let!(:pending_record)   { create(:search_trend_hourly, processed: false) }
    let!(:processed_record) { create(:search_trend_hourly, processed: true) }

    it "includes records with processed = false" do
      expect(SearchTrendHourly.unprocessed).to include(pending_record)
    end

    it "excludes records with processed = true" do
      expect(SearchTrendHourly.unprocessed).not_to include(processed_record)
    end
  end

  # -------------------------------------------------------------------------
  # .processed
  # -------------------------------------------------------------------------
  describe ".processed" do
    let!(:pending_record)   { create(:search_trend_hourly, processed: false) }
    let!(:processed_record) { create(:search_trend_hourly, processed: true) }

    it "includes records with processed = true" do
      expect(SearchTrendHourly.processed).to include(processed_record)
    end

    it "excludes records with processed = false" do
      expect(SearchTrendHourly.processed).not_to include(pending_record)
    end
  end

  # -------------------------------------------------------------------------
  # .unprocessed_before
  # -------------------------------------------------------------------------
  describe ".unprocessed_before" do
    let(:cutoff) { Time.utc(2026, 1, 15, 8, 0, 0) }

    let!(:before_unprocessed)    { create(:search_trend_hourly, hour: Time.utc(2026, 1, 15, 6, 0, 0), processed: false) }
    let!(:at_cutoff_unprocessed) { create(:search_trend_hourly, hour: cutoff,                         processed: false) }
    let!(:before_processed)      { create(:search_trend_hourly, hour: Time.utc(2026, 1, 15, 6, 0, 0), processed: true) }

    it "returns unprocessed records whose hour is strictly before the cutoff" do
      expect(SearchTrendHourly.unprocessed_before(cutoff)).to include(before_unprocessed)
    end

    it "excludes unprocessed records at the cutoff time" do
      expect(SearchTrendHourly.unprocessed_before(cutoff)).not_to include(at_cutoff_unprocessed)
    end

    it "excludes processed records even if their hour is before the cutoff" do
      expect(SearchTrendHourly.unprocessed_before(cutoff)).not_to include(before_processed)
    end
  end
end
