# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          SearchTrend Scopes                                 #
# --------------------------------------------------------------------------- #
#
# All fixtures use fixed UTC dates so scope boundaries are deterministic
# regardless of when the test suite runs.

RSpec.describe SearchTrend do
  # -------------------------------------------------------------------------
  # .for_day
  # -------------------------------------------------------------------------
  describe ".for_day" do
    let!(:on_day)   { create(:search_trend, day: Date.new(2026, 1, 15)) }
    let!(:next_day) { create(:search_trend, day: Date.new(2026, 1, 16)) }
    let!(:prev_day) { create(:search_trend, day: Date.new(2026, 1, 14)) }

    it "returns records for the given date" do
      expect(SearchTrend.for_day(Date.new(2026, 1, 15))).to include(on_day)
    end

    it "excludes records from the following day" do
      expect(SearchTrend.for_day(Date.new(2026, 1, 15))).not_to include(next_day)
    end

    it "excludes records from the preceding day" do
      expect(SearchTrend.for_day(Date.new(2026, 1, 15))).not_to include(prev_day)
    end

    it "orders by count descending" do
      low  = create(:search_trend, day: Date.new(2026, 1, 15), count: 5)
      high = create(:search_trend, day: Date.new(2026, 1, 15), count: 50)
      result = SearchTrend.for_day(Date.new(2026, 1, 15)).to_a
      expect(result.index(high)).to be < result.index(low)
    end

    it "orders by tag ascending when counts are equal" do
      create(:search_trend, tag: "zzz_tag", day: Date.new(2026, 1, 15), count: 10)
      create(:search_trend, tag: "aaa_tag", day: Date.new(2026, 1, 15), count: 10)
      result = SearchTrend.for_day(Date.new(2026, 1, 15)).select { |r| r.count == 10 }
      expect(result.map(&:tag)).to eq(result.map(&:tag).sort)
    end
  end

  # -------------------------------------------------------------------------
  # .for_day_ranked
  # -------------------------------------------------------------------------
  describe ".for_day_ranked" do
    let(:target_day) { Date.new(2026, 3, 1) }

    let!(:first_place)  { create(:search_trend, tag: "aaa_top",    day: target_day, count: 100) }
    let!(:second_place) { create(:search_trend, tag: "bbb_second", day: target_day, count: 50) }
    let!(:third_place)  { create(:search_trend, tag: "ccc_third",  day: target_day, count: 10) }
    let!(:other_day)    { create(:search_trend, day: Date.new(2026, 3, 2)) }

    it "returns records for the given date" do
      expect(SearchTrend.for_day_ranked(target_day)).to include(first_place, second_place, third_place)
    end

    it "excludes records from a different date" do
      expect(SearchTrend.for_day_ranked(target_day)).not_to include(other_day)
    end

    it "assigns daily_rank = 1 to the highest-count record" do
      result = SearchTrend.for_day_ranked(target_day).first
      expect(result[:daily_rank]).to eq(1)
    end

    it "assigns incrementing ranks in count-descending order" do
      results = SearchTrend.for_day_ranked(target_day).to_a
      ranks = results.pluck(:daily_rank)
      expect(ranks).to eq((1..ranks.length).to_a)
    end
  end

  # -------------------------------------------------------------------------
  # .for_tag
  # -------------------------------------------------------------------------
  describe ".for_tag" do
    let!(:target) { create(:search_trend, tag: "fox") }
    let!(:other)  { create(:search_trend, tag: "wolf") }

    it "returns records matching the given tag" do
      expect(SearchTrend.for_tag("fox")).to include(target)
    end

    it "excludes records with a different tag" do
      expect(SearchTrend.for_tag("fox")).not_to include(other)
    end

    it "normalizes the input by downcasing" do
      expect(SearchTrend.for_tag("FOX")).to include(target)
    end

    it "normalizes the input by stripping surrounding whitespace" do
      expect(SearchTrend.for_tag("  fox  ")).to include(target)
    end
  end

  # -------------------------------------------------------------------------
  # .for_tags
  # -------------------------------------------------------------------------
  describe ".for_tags" do
    # Use dates relative to today so they always fall inside the 30-day window.
    let(:today)      { Time.now.utc.to_date }
    let(:recent_day) { today - 5 }
    let(:old_day)    { today - 31 }

    before do
      create(:search_trend, tag: "fox",  day: recent_day, count: 10)
      create(:search_trend, tag: "wolf", day: recent_day, count: 5)
      create(:search_trend, tag: "fox",  day: old_day,    count: 3)
    end

    it "includes records within the last 30 days for the requested tags" do
      result = SearchTrend.for_tags(["fox"])
      tags_and_days = result.map { |r| [r.tag, r.day] }
      expect(tags_and_days).to include(["fox", recent_day])
    end

    it "excludes records older than 30 days" do
      result = SearchTrend.for_tags(["fox"])
      tags_and_days = result.map { |r| [r.tag, r.day] }
      expect(tags_and_days).not_to include(["fox", old_day])
    end

    it "excludes tags not in the requested list" do
      result = SearchTrend.for_tags(["fox"])
      expect(result.map(&:tag)).not_to include("wolf")
    end

    it "returns the count from the existing record" do
      result = SearchTrend.for_tags(["fox"])
      fox_row = result.find { |r| r.tag == "fox" && r.day == recent_day }
      expect(fox_row.count).to eq(10)
    end

    it "orders results by tag ascending, then day ascending" do
      result = SearchTrend.for_tags(%w[wolf fox]).to_a
      tags = result.map(&:tag)
      expect(tags).to eq(tags.sort)
    end
  end
end
