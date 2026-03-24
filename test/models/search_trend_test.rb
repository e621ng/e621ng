# frozen_string_literal: true

require "test_helper"

class SearchTrendTest < ActiveSupport::TestCase
  setup do
    Setting.trends_enabled = true
  end

  teardown do
    Setting.trends_enabled = false
  end

  test "increment! creates an hourly record and increments it" do
    hour = Time.now.utc.hour
    assert_difference -> { SearchTrend.count }, +1 do
      SearchTrend.increment!("Test_Tag")
    end
    rec = SearchTrend.find_by(tag: "test_tag", day: Time.now.utc.to_date, hour: hour)
    assert_not_nil rec
    assert_equal 1, rec.count

    assert_no_difference -> { SearchTrend.count } do
      SearchTrend.increment!("test_tag")
    end
    rec.reload
    assert_equal 2, rec.count
  end

  test "bulk_increment! handles multiple tags and de-dupes" do
    SearchTrend.bulk_increment!(%w[alpha beta alpha]) # alpha counted once
    rows = SearchTrend.for_day(Date.current).pluck(:tag, :count).to_h
    assert_equal({ "alpha" => 1, "beta" => 1 }, rows)
  end

  test "rising returns tags with substantial same-window increase, ordered by today count" do
    # Fix 'at' to 3 PM so the window (hours 4..15) is within a single day,
    # keeping the test independent of the real hour.
    at      = Time.current.change(hour: 15)
    today   = at.to_date
    yesterday = today - 1

    # Records at hour 10 — inside both today's and yesterday's 4..15 window
    SearchTrend.create!(tag: "low",   day: today,     hour: 10, count: 5) # below min_today

    # Delta-based inclusion (30 - 10 = 20 >= min_delta 10)
    SearchTrend.create!(tag: "foo",   day: yesterday, hour: 10, count: 10)
    SearchTrend.create!(tag: "foo",   day: today,     hour: 10, count: 30)

    # Ratio-based inclusion (12/5 = 2.4 >= min_ratio 2.0, delta 7 < 10)
    SearchTrend.create!(tag: "ratio", day: yesterday, hour: 10, count: 5)
    SearchTrend.create!(tag: "ratio", day: today,     hour: 10, count: 12)

    # Delta-based inclusion (no yesterday record, 15 >= 10)
    SearchTrend.create!(tag: "baz",   day: today,     hour: 10, count: 15)

    # Not included (delta 5 < 10, ratio 1.25 < 2.0)
    SearchTrend.create!(tag: "bar",   day: yesterday, hour: 10, count: 20)
    SearchTrend.create!(tag: "bar",   day: today,     hour: 10, count: 25)

    rising = SearchTrend.rising(at: at, limit: 10)
    assert_equal %w[foo baz ratio], rising.pluck(:tag)
  end

  test "rising spans midnight correctly when window crosses into the previous day" do
    # at = 3 AM today; window_hours=12 covers today(0..3) + yesterday(16..23)
    at        = Time.current.change(hour: 3)
    today     = at.to_date
    yesterday = today - 1
    day_before = yesterday - 1

    # Today hours 0..3 (inside window)
    SearchTrend.create!(tag: "cross", day: today,     hour: 2,  count: 20)
    # Yesterday hours 16..23 (inside window)
    SearchTrend.create!(tag: "cross", day: yesterday, hour: 20, count: 5)
    # "Yesterday's window" for the comparison = yesterday(0..3) + day_before(16..23)
    SearchTrend.create!(tag: "cross", day: yesterday, hour: 2,  count: 2)
    SearchTrend.create!(tag: "cross", day: day_before, hour: 20, count: 1)

    # tag "cross" today_sum = 20+5 = 25, prev_sum = 2+1 = 3; delta 22 >= 10, ratio 8.3 >= 2.0
    rising = SearchTrend.rising(at: at, limit: 10)
    assert_includes rising.pluck(:tag), "cross"
  end

  test "coalesce_hourly! merges old hourly records into daily aggregates" do
    today      = Date.current
    old_day    = today - 3
    recent_day = today - 1

    # Old hourly records (> 48 h ago) — should be coalesced
    SearchTrend.create!(tag: "owl", day: old_day, hour: 5,  count: 10)
    SearchTrend.create!(tag: "owl", day: old_day, hour: 10, count: 15)

    # Recent hourly record (< 48 h ago) — should be left alone
    SearchTrend.create!(tag: "owl", day: recent_day, hour: 22, count: 3)

    SearchTrend.coalesce_hourly!

    # Old day: daily record created, hourly records deleted
    daily = SearchTrend.find_by!(tag: "owl", day: old_day, hour: nil)
    assert_equal 25, daily.count
    assert_equal 0, SearchTrend.where(tag: "owl", day: old_day).where.not(hour: nil).count

    # Recent record: untouched
    assert SearchTrend.where(tag: "owl", day: recent_day, hour: 22).exists?
  end

  test "coalesce_hourly! adds to existing daily record when one already exists" do
    old_day = Date.current - 3

    SearchTrend.create!(tag: "cat", day: old_day, hour: nil, count: 50)
    SearchTrend.create!(tag: "cat", day: old_day, hour: 4,   count: 30)

    SearchTrend.coalesce_hourly!

    daily = SearchTrend.find_by!(tag: "cat", day: old_day, hour: nil)
    assert_equal 80, daily.count
    assert_equal 0, SearchTrend.where(tag: "cat", day: old_day).where.not(hour: nil).count
  end

  test "prune! only removes old low-count daily records, not hourly records" do
    old_day = Date.current - 3

    low_daily  = SearchTrend.create!(tag: "prune_me",  day: old_day, hour: nil, count: 1)
    keep_daily = SearchTrend.create!(tag: "keep_me",   day: old_day, hour: nil, count: 999)
    hourly     = SearchTrend.create!(tag: "prune_me",  day: old_day, hour: 5,   count: 1)

    SearchTrend.prune!(min_count: 10)

    assert_not SearchTrend.exists?(low_daily.id),  "low-count daily should be pruned"
    assert     SearchTrend.exists?(keep_daily.id), "high-count daily should be kept"
    assert     SearchTrend.exists?(hourly.id),     "hourly record should never be pruned"
  end

  # --- record_query! ---

  test "record_query! records plain tags" do
    SearchTrend.record_query!("cat dog")
    tags = SearchTrend.for_day(Date.current).pluck(:tag)
    assert_includes tags, "cat"
    assert_includes tags, "dog"
  end

  test "record_query! strips the ~ prefix and records the tag" do
    SearchTrend.record_query!("~wolf")
    assert SearchTrend.for_day(Date.current).where(tag: "wolf").exists?
  end

  test "record_query! excludes tags with the - prefix" do
    SearchTrend.record_query!("-fox")
    assert_not SearchTrend.for_day(Date.current).where(tag: "fox").exists?
  end

  test "record_query! excludes tags with a ~- compound prefix" do
    SearchTrend.record_query!("~-cat")
    assert_not SearchTrend.for_day(Date.current).where(tag: "cat").exists?
  end

  test "record_query! handles a mixed query correctly" do
    SearchTrend.record_query!("cat ~dog -fox ~-bird")
    tags = SearchTrend.for_day(Date.current).pluck(:tag)
    assert_includes     tags, "cat"
    assert_includes     tags, "dog"   # ~ stripped
    assert_not_includes tags, "fox"   # - excluded
    assert_not_includes tags, "bird"  # ~- excluded
  end

  test "record_query! excludes all tags inside a negated group" do
    SearchTrend.record_query!("-( cat dog )")
    tags = SearchTrend.for_day(Date.current).pluck(:tag)
    assert_not_includes tags, "cat"
    assert_not_includes tags, "dog"
  end

  test "record_query! records tags from a ~ group without prefix" do
    SearchTrend.record_query!("~( cat dog )")
    tags = SearchTrend.for_day(Date.current).pluck(:tag)
    assert_includes tags, "cat"
    assert_includes tags, "dog"
  end

  test "record_query! excludes tags inside a doubly-negated group" do
    SearchTrend.record_query!("-( ~( cat ) )")
    assert_not SearchTrend.for_day(Date.current).where(tag: "cat").exists?
  end

  test "record_query! skips metatags" do
    SearchTrend.record_query!("cat rating:s score:>10")
    tags = SearchTrend.for_day(Date.current).pluck(:tag)
    assert_includes     tags, "cat"
    assert_not_includes tags, "rating:s"
    assert_not_includes tags, "score:>10"
  end

  test "record_query! does nothing for a blank query" do
    assert_no_difference -> { SearchTrend.count } do
      SearchTrend.record_query!(nil)
      SearchTrend.record_query!("")
      SearchTrend.record_query!("   ")
    end
  end

  test "record_query! swallows errors and does not raise" do
    # Pass an object whose #blank? returns false but causes scan_recursive to blow up.
    bad_query = Object.new
    def bad_query.blank? = false
    assert_nothing_raised { SearchTrend.record_query!(bad_query) }
  end
end
