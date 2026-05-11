# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   SearchTrendHourly Class Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendHourly do
  # =========================================================================
  # .record_query!
  # =========================================================================
  #
  # record_query! parses a raw tag query string, extracts plain affirmative
  # tags, and forwards them to bulk_increment!. We stub bulk_increment! here
  # to isolate the parsing logic.
  # =========================================================================
  describe ".record_query!" do
    let(:fixed_hour) { Time.utc(2026, 1, 1, 10, 0, 0) }

    before do
      allow(SearchTrendHourly).to receive(:bulk_increment!)
      allow(Setting).to receive(:trends_enabled).and_return(true)
    end

    it "does not call bulk_increment! when the query is nil" do
      SearchTrendHourly.record_query!(nil, hour: fixed_hour)
      expect(SearchTrendHourly).not_to have_received(:bulk_increment!)
    end

    it "does not call bulk_increment! when the query is blank" do
      SearchTrendHourly.record_query!("   ", hour: fixed_hour)
      expect(SearchTrendHourly).not_to have_received(:bulk_increment!)
    end

    it "calls bulk_increment! with plain tags extracted from the query" do
      SearchTrendHourly.record_query!("fox wolf", hour: fixed_hour)
      expect(SearchTrendHourly).to have_received(:bulk_increment!).with(
        include(
          hash_including(tag: "fox"),
          hash_including(tag: "wolf"),
        ),
        ip: nil,
      )
    end

    it "strips the ~ prefix from or-tags before recording" do
      SearchTrendHourly.record_query!("~fox", hour: fixed_hour)
      expect(SearchTrendHourly).to have_received(:bulk_increment!).with(
        include(hash_including(tag: "fox")),
        ip: nil,
      )
    end

    it "excludes negated tags with a - prefix" do
      SearchTrendHourly.record_query!("-fox wolf", hour: fixed_hour)
      expect(SearchTrendHourly).to have_received(:bulk_increment!) do |tags, **|
        tag_names = tags.pluck(:tag)
        expect(tag_names).not_to include("fox")
        expect(tag_names).to include("wolf")
      end
    end

    it "does not call bulk_increment! when all tags are negated" do
      SearchTrendHourly.record_query!("-fox -wolf", hour: fixed_hour)
      expect(SearchTrendHourly).not_to have_received(:bulk_increment!)
    end

    it "excludes metatags (tokens containing :)" do
      SearchTrendHourly.record_query!("type:png fox", hour: fixed_hour)
      expect(SearchTrendHourly).to have_received(:bulk_increment!) do |tags, **|
        tag_names = tags.pluck(:tag)
        expect(tag_names).not_to include("type:png")
        expect(tag_names).to include("fox")
      end
    end

    it "does not raise when tag parsing encounters a StandardError" do
      allow(TagQuery).to receive(:scan_recursive).and_raise(StandardError, "parse error")
      expect { SearchTrendHourly.record_query!("fox", hour: fixed_hour) }.not_to raise_error
    end
  end

  # =========================================================================
  # .bulk_increment!
  # =========================================================================
  #
  # bulk_increment! writes to the DB via a raw SQL upsert.
  # Dependencies that go outside the model layer (Setting, blacklist,
  # RateLimiter) are stubbed so the unit test remains hermetic.
  # =========================================================================
  describe ".bulk_increment!" do
    let(:fixed_hour) { Time.utc(2026, 1, 1, 10, 0, 0) }

    before do
      allow(Setting).to receive_messages(
        trends_enabled: true,
        trends_ip_limit: 1000,
        trends_ip_window: 60,
        trends_tag_limit: 1000,
        trends_tag_window: 60,
      )
      allow(SearchTrendBlacklist).to receive(:blacklisted?).and_return(false)
      allow(RateLimiter).to receive(:check_limit).and_return(false)
      allow(RateLimiter).to receive(:hit)
    end

    it "does not write to the DB when data is blank" do
      expect { SearchTrendHourly.bulk_increment!([], ip: nil) }
        .not_to change(SearchTrendHourly, :count)
    end

    it "does not write to the DB when Setting.trends_enabled is false" do
      allow(Setting).to receive(:trends_enabled).and_return(false)
      expect { SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: fixed_hour }]) }
        .not_to change(SearchTrendHourly, :count)
    end

    it "creates a new record with count = 1 for a new tag-hour pair" do
      SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: fixed_hour }])
      record = SearchTrendHourly.for_tag("fox").for_hour(fixed_hour).first
      expect(record).not_to be_nil
      expect(record.count).to eq(1)
    end

    it "increments the count on an existing record when the tag-hour pair already exists" do
      create(:search_trend_hourly, tag: "fox", hour: fixed_hour, count: 5)
      SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: fixed_hour }])
      expect(SearchTrendHourly.for_tag("fox").for_hour(fixed_hour).first.count).to eq(6)
    end

    it "normalizes tags to lowercase" do
      SearchTrendHourly.bulk_increment!([{ tag: "FOX", hour: fixed_hour }])
      expect(SearchTrendHourly.for_tag("fox").for_hour(fixed_hour).first).not_to be_nil
    end

    it "normalizes tags by stripping surrounding whitespace" do
      SearchTrendHourly.bulk_increment!([{ tag: "  fox  ", hour: fixed_hour }])
      expect(SearchTrendHourly.for_tag("fox").for_hour(fixed_hour).first).not_to be_nil
    end

    it "skips tags that are blank after normalization" do
      expect { SearchTrendHourly.bulk_increment!([{ tag: "   ", hour: fixed_hour }]) }
        .not_to change(SearchTrendHourly, :count)
    end

    it "skips tags that exceed 100 characters" do
      expect { SearchTrendHourly.bulk_increment!([{ tag: "a" * 101, hour: fixed_hour }]) }
        .not_to change(SearchTrendHourly, :count)
    end

    it "skips blacklisted tags" do
      allow(SearchTrendBlacklist).to receive(:blacklisted?).with("fox").and_return(true)
      expect { SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: fixed_hour }]) }
        .not_to change(SearchTrendHourly, :count)
    end

    it "returns early without any DB writes when the IP rate limit is exceeded" do
      allow(RateLimiter).to receive(:check_limit).with("trends:ip:1.2.3.4", anything, anything).and_return(true)
      expect { SearchTrendHourly.bulk_increment!([{ tag: "fox", hour: fixed_hour }], ip: "1.2.3.4") }
        .not_to change(SearchTrendHourly, :count)
    end

    it "skips rate-limited tags but still writes other tags in the same batch" do
      allow(RateLimiter).to receive(:check_limit).with("trends:tag:slow_tag", anything, anything).and_return(true)
      allow(RateLimiter).to receive(:check_limit).with("trends:tag:fast_tag", anything, anything).and_return(false)

      data = [
        { tag: "slow_tag", hour: fixed_hour },
        { tag: "fast_tag", hour: fixed_hour },
      ]
      SearchTrendHourly.bulk_increment!(data)

      expect(SearchTrendHourly.for_tag("fast_tag").for_hour(fixed_hour).first).not_to be_nil
      expect(SearchTrendHourly.for_tag("slow_tag").for_hour(fixed_hour).first).to be_nil
    end
  end

  # =========================================================================
  # .warm_rising_tags_cache!
  # =========================================================================
  #
  # warm_rising_tags_cache! unconditionally computes and writes the rising tags
  # list to the cache with a 20-minute TTL (longer than rising_tags_list's
  # 15-minute TTL so the job-scheduled writes never expire between runs).
  # =========================================================================
  describe ".warm_rising_tags_cache!" do
    before do
      allow(Cache).to receive(:write)
      allow(Setting).to receive_messages(
        trends_min_today: 1,
        trends_min_delta: 1,
        trends_min_ratio: 1.0,
      )
    end

    it "writes to the rising_tags cache key with a 20-minute TTL" do
      SearchTrendHourly.warm_rising_tags_cache!
      expect(Cache).to have_received(:write).with("rising_tags", anything, expires_in: 20.minutes)
    end

    it "returns the computed list" do
      result = SearchTrendHourly.warm_rising_tags_cache!
      expect(result).to be_an(Array)
    end
  end

  # =========================================================================
  # .prune!
  # =========================================================================
  #
  # prune! removes processed hourly records older than 48 hours.
  # We use relative times so the tests remain correct on any run date.
  # =========================================================================
  describe ".prune!" do
    it "deletes processed records whose hour is more than 48 hours ago" do
      old_processed = create(:search_trend_hourly,
                             processed: true,
                             hour: 49.hours.ago.utc.beginning_of_hour)
      SearchTrendHourly.prune!
      expect(SearchTrendHourly.exists?(old_processed.id)).to be false
    end

    it "does not delete processed records whose hour is within the 48-hour window" do
      recent_processed = create(:search_trend_hourly,
                                processed: true,
                                hour: 47.hours.ago.utc.beginning_of_hour)
      SearchTrendHourly.prune!
      expect(SearchTrendHourly.exists?(recent_processed.id)).to be true
    end

    it "does not delete unprocessed records even if their hour is more than 48 hours ago" do
      old_unprocessed = create(:search_trend_hourly,
                               processed: false,
                               hour: 49.hours.ago.utc.beginning_of_hour)
      SearchTrendHourly.prune!
      expect(SearchTrendHourly.exists?(old_unprocessed.id)).to be true
    end

    it "does not raise when there are no records to delete" do
      expect { SearchTrendHourly.prune! }.not_to raise_error
    end
  end

  # =========================================================================
  # .rising
  # =========================================================================
  #
  # rising compares counts in the current 12-hour window against the previous
  # 12-hour window and returns tags that have grown above the given thresholds.
  #
  # Fixed reference point so window boundaries never cross a test run:
  #   at              = 2026-01-01 12:00:00 UTC
  #   current window  = 2025-12-31 12:00:00 UTC .. 2026-01-01 12:00:00 UTC  (24 h)
  #   previous window = 2025-12-30 12:00:00 UTC ..< 2025-12-31 12:00:00 UTC (24 h)
  # =========================================================================
  describe ".rising" do
    let(:at)          { Time.utc(2026, 1, 1, 12, 0, 0) }
    let(:current_hr)  { Time.utc(2026, 1, 1, 6, 0, 0) }    # inside current window
    let(:previous_hr) { Time.utc(2025, 12, 31, 6, 0, 0) }  # inside previous window

    # Call rising with the fixed reference time and sensible defaults.
    def call_rising(**overrides)
      SearchTrendHourly.rising(
        at: at,
        limit: 10,
        min_today: 10,
        min_delta: 10,
        min_ratio: 2.0,
        **overrides,
      )
    end

    it "returns an empty array when there are no records in the current window" do
      expect(call_rising).to eq([])
    end

    it "returns TrendingTag structs with tag, search_count, and delta accessors" do
      create(:search_trend_hourly, tag: "new_tag", hour: current_hr, count: 20)
      result = call_rising
      expect(result.first).to respond_to(:tag, :search_count, :delta)
    end

    it "includes a brand-new tag (zero previous count) when count meets both thresholds" do
      # previous = 0, current = 20, delta = 20 — ratio check bypassed when previous = 0
      create(:search_trend_hourly, tag: "new_tag", hour: current_hr, count: 20)
      expect(call_rising.map(&:tag)).to include("new_tag")
    end

    it "excludes a tag whose current count is below min_today" do
      create(:search_trend_hourly, tag: "rare_tag", hour: current_hr, count: 5)
      expect(call_rising(min_today: 10).map(&:tag)).not_to include("rare_tag")
    end

    it "excludes a tag whose delta is below min_delta" do
      # previous = 15, current = 20, delta = 5 — below min_delta of 10
      create(:search_trend_hourly, tag: "slow_tag", hour: previous_hr, count: 15)
      create(:search_trend_hourly, tag: "slow_tag", hour: current_hr,  count: 20)
      expect(call_rising(min_delta: 10).map(&:tag)).not_to include("slow_tag")
    end

    it "excludes a tag where previous_count > 0 and ratio is below min_ratio" do
      # previous = 10, current = 15, delta = 5, ratio = 1.5 — below min_ratio of 2.0
      create(:search_trend_hourly, tag: "weak_ratio", hour: previous_hr, count: 10)
      create(:search_trend_hourly, tag: "weak_ratio", hour: current_hr,  count: 15)
      expect(call_rising(min_delta: 1, min_ratio: 2.0).map(&:tag)).not_to include("weak_ratio")
    end

    it "includes a tag where previous_count > 0 and both ratio and delta meet thresholds" do
      # previous = 5, current = 20, delta = 15, ratio = 4.0
      create(:search_trend_hourly, tag: "hot_tag", hour: previous_hr, count: 5)
      create(:search_trend_hourly, tag: "hot_tag", hour: current_hr,  count: 20)
      expect(call_rising.map(&:tag)).to include("hot_tag")
    end

    it "reports the correct search_count and delta on returned structs" do
      create(:search_trend_hourly, tag: "hot_tag", hour: previous_hr, count: 5)
      create(:search_trend_hourly, tag: "hot_tag", hour: current_hr,  count: 20)
      result = call_rising.find { |t| t.tag == "hot_tag" }
      expect(result.search_count).to eq(20)
      expect(result.delta).to eq(15)
    end

    it "sorts results by current count descending" do
      create(:search_trend_hourly, tag: "aaa_tag", hour: current_hr, count: 30)
      create(:search_trend_hourly, tag: "bbb_tag", hour: current_hr, count: 20)
      tags = call_rising.map(&:tag)
      expect(tags.index("aaa_tag")).to be < tags.index("bbb_tag")
    end

    it "sorts by tag name ascending when counts are equal" do
      create(:search_trend_hourly, tag: "zzz_tag", hour: current_hr, count: 20)
      create(:search_trend_hourly, tag: "aaa_tag", hour: current_hr, count: 20)
      tags = call_rising.map(&:tag)
      expect(tags.index("aaa_tag")).to be < tags.index("zzz_tag")
    end

    it "limits results to the given limit" do
      5.times { |i| create(:search_trend_hourly, tag: "tag_#{i + 1}", hour: current_hr, count: 20) }
      expect(call_rising(limit: 3).size).to eq(3)
    end
  end
end
