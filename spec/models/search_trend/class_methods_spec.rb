# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     SearchTrend Class Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrend do
  # =========================================================================
  # .for_graph
  # =========================================================================
  #
  # for_graph builds a 30-day rolling window (30.days.ago.to_date..today UTC)
  # for each requested tag, filling in zero-count unsaved records for days
  # where no data exists in the DB.
  #
  # Records are created with dates relative to today so the window always
  # contains them regardless of when the suite runs.
  # =========================================================================
  describe ".for_graph" do
    let(:today)      { Time.now.utc.to_date }
    let(:yesterday)  { today - 1 }
    let(:five_ago)   { today - 5 }

    it "returns a Hash" do
      expect(SearchTrend.for_graph(["fox"])).to be_a(Hash)
    end

    it "keys the Hash by normalized (downcased) tag name" do
      create(:search_trend, tag: "fox", day: yesterday, count: 10)
      result = SearchTrend.for_graph(["FOX"])
      expect(result.keys).to include("fox")
    end

    it "returns an entry for every requested tag, even unknown ones" do
      result = SearchTrend.for_graph(%w[fox wolf])
      expect(result.keys).to contain_exactly("fox", "wolf")
    end

    it "returns 31 entries per tag (30-day window, both endpoints inclusive)" do
      result = SearchTrend.for_graph(["fox"])
      expect(result["fox"].length).to eq(31)
    end

    it "places a DB record at the correct day position with the correct count" do
      create(:search_trend, tag: "fox", day: yesterday, count: 42)
      series = SearchTrend.for_graph(["fox"])["fox"]
      entry = series.find { |r| r.day == yesterday }
      expect(entry).not_to be_nil
      expect(entry.count).to eq(42)
    end

    it "fills days with no data with unsaved records having count = 0" do
      create(:search_trend, tag: "fox", day: yesterday, count: 10)
      series = SearchTrend.for_graph(["fox"])["fox"]
      zero_entries = series.reject { |r| r.day == yesterday }
      expect(zero_entries).to all(satisfy { |r| !r.persisted? && r.count == 0 })
    end

    it "returns all zero-count unsaved records for a tag with no DB data" do
      series = SearchTrend.for_graph(["no_data_tag"])["no_data_tag"]
      expect(series).to all(satisfy { |r| !r.persisted? && r.count == 0 })
    end

    it "covers days from 30 days ago through today" do
      series = SearchTrend.for_graph(["fox"])["fox"]
      days = series.map(&:day)
      expect(days.min).to eq(30.days.ago.to_date)
      expect(days.max).to eq(today)
    end

    it "uses existing DB records when multiple tags are requested together" do
      create(:search_trend, tag: "fox",  day: five_ago, count: 7)
      create(:search_trend, tag: "wolf", day: five_ago, count: 3)
      result = SearchTrend.for_graph(%w[fox wolf])
      expect(result["fox"].find { |r| r.day == five_ago }.count).to eq(7)
      expect(result["wolf"].find { |r| r.day == five_ago }.count).to eq(3)
    end
  end

  # =========================================================================
  # .prune!
  # =========================================================================
  #
  # prune! deletes records strictly before today (UTC) whose count is below
  # the given minimum threshold (default: Danbooru.config.search_trend_minimum_count).
  # =========================================================================
  describe ".prune!" do
    let(:today)      { Time.now.utc.to_date }
    let(:yesterday)  { today - 1 }

    it "deletes a past record whose count is below min_count" do
      old_low = create(:search_trend, day: yesterday, count: 1)
      SearchTrend.prune!(min_count: 5)
      expect(SearchTrend.exists?(old_low.id)).to be false
    end

    it "preserves a past record whose count meets min_count" do
      old_high = create(:search_trend, day: yesterday, count: 5)
      SearchTrend.prune!(min_count: 5)
      expect(SearchTrend.exists?(old_high.id)).to be true
    end

    it "preserves a past record whose count exceeds min_count" do
      old_high = create(:search_trend, day: yesterday, count: 10)
      SearchTrend.prune!(min_count: 5)
      expect(SearchTrend.exists?(old_high.id)).to be true
    end

    it "preserves today's record even when its count is below min_count" do
      todays = create(:search_trend, day: today, count: 1)
      SearchTrend.prune!(min_count: 5)
      expect(SearchTrend.exists?(todays.id)).to be true
    end

    it "does not raise when there are no records to delete" do
      expect { SearchTrend.prune!(min_count: 5) }.not_to raise_error
    end
  end
end
