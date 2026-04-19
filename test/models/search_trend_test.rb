# frozen_string_literal: true

require "test_helper"

class SearchTrendTest < ActiveSupport::TestCase
  setup do
    Setting.trends_enabled = true
  end

  teardown do
    Setting.trends_enabled = false
  end

  test "bulk_increment! creates an hourly record and increments it" do
    hour = 1.hour.ago.utc.beginning_of_hour
    assert_difference -> { SearchTrendHourly.count }, +1 do
      SearchTrendHourly.bulk_increment!([{ tag: "Test_Tag", hour: hour }])
    end
    rec = SearchTrendHourly.find_by(tag: "test_tag", hour: hour)
    assert_not_nil rec
    assert_equal 1, rec.count

    assert_no_difference -> { SearchTrendHourly.count } do
      SearchTrendHourly.bulk_increment!([{ tag: "test_tag", hour: hour }])
    end
    rec.reload
    assert_equal 2, rec.count
  end

  test "bulk_increment! handles multiple tags and de-dupes" do
    hour = 1.hour.ago.utc.beginning_of_hour
    SearchTrendHourly.bulk_increment!([{ tag: "alpha", hour: hour }, { tag: "beta", hour: hour }, { tag: "alpha", hour: hour }]) # alpha counted twice
    rows = SearchTrendHourly.for_day(hour.to_date).pluck(:tag, :count).to_h
    assert_equal({ "alpha" => 2, "beta" => 1 }, rows)
  end

  test "rising returns tags with substantial same-window increase, ordered by today count" do
    # Fix 'at' to 3 PM so the window (hours 4..15) is within a single day,
    # keeping the test independent of the real hour.
    at      = Time.current.change(hour: 15)
    today   = at.to_date
    yesterday = today - 1

    # Current window: 3 AM today → 3 PM today (12 hours)
    # Previous window: 3 PM yesterday → 3 AM today (12 hours)
    # Create records at times that fall within both windows

    # Records at hour 10 today (current window) and hour 22 yesterday (previous window)
    SearchTrendHourly.create!(tag: "low", hour: today.beginning_of_day + 10.hours, count: 5) # below min_today

    # Delta-based inclusion (30 - 10 = 20 >= min_delta 10)
    SearchTrendHourly.create!(tag: "foo", hour: yesterday.beginning_of_day + 22.hours, count: 10)
    SearchTrendHourly.create!(tag: "foo", hour: today.beginning_of_day + 10.hours, count: 30)

    # Ratio-based inclusion (15/2 = 7.5 >= min_ratio 2.0, delta 13 >= 10)
    SearchTrendHourly.create!(tag: "ratio", hour: yesterday.beginning_of_day + 22.hours, count: 2)
    SearchTrendHourly.create!(tag: "ratio", hour: today.beginning_of_day + 10.hours, count: 15)

    # Delta-based inclusion (no yesterday record, 15 >= 10)
    SearchTrendHourly.create!(tag: "baz", hour: today.beginning_of_day + 10.hours, count: 15)

    # Not included (delta 5 < 10, ratio 1.25 < 2.0)
    SearchTrendHourly.create!(tag: "bar", hour: yesterday.beginning_of_day + 22.hours, count: 20)
    SearchTrendHourly.create!(tag: "bar", hour: today.beginning_of_day + 10.hours, count: 25)

    rising = SearchTrendHourly.rising(at: at, limit: 10)
    assert_equal %w[foo baz ratio], rising.map(&:tag)
  end

  test "rising spans midnight correctly when window crosses into the previous day" do
    # at = 3 AM today; window_hours=12 covers today(0..3) + yesterday(16..23)
    at        = Time.current.change(hour: 3)
    today     = at.to_date
    yesterday = today - 1
    day_before = yesterday - 1

    # Today hours 0..3 (inside window)
    SearchTrendHourly.create!(tag: "cross", hour: today.beginning_of_day + 2.hours, count: 20)
    # Yesterday hours 16..23 (inside window)
    SearchTrendHourly.create!(tag: "cross", hour: yesterday.beginning_of_day + 20.hours, count: 5)
    # "Yesterday's window" for the comparison = yesterday(0..3) + day_before(16..23)
    SearchTrendHourly.create!(tag: "cross", hour: yesterday.beginning_of_day + 2.hours, count: 2)
    SearchTrendHourly.create!(tag: "cross", hour: day_before.beginning_of_day + 20.hours, count: 1)

    # tag "cross" today_sum = 20+5 = 25, prev_sum = 2+1 = 3; delta 22 >= 10, ratio 8.3 >= 2.0
    rising = SearchTrendHourly.rising(at: at, limit: 10)
    assert_includes rising.map(&:tag), "cross"
  end

  test "prune! only removes old low-count daily records" do
    old_day = Time.now.utc.to_date - 3

    low_daily  = SearchTrend.create!(tag: "prune_me", day: old_day, count: 1)
    keep_daily = SearchTrend.create!(tag: "keep_me",  day: old_day, count: 999)

    SearchTrend.prune!(min_count: 10)

    assert_not SearchTrend.exists?(low_daily.id),  "low-count daily should be pruned"
    assert     SearchTrend.exists?(keep_daily.id), "high-count daily should be kept"
  end

  test "for_day_ranked includes daily_rank column ordered by count DESC, tag ASC" do
    day = Time.now.utc.to_date

    # Create trends with different counts to test ranking
    SearchTrend.create!(tag: "zebra", day: day, count: 100)
    SearchTrend.create!(tag: "alpha", day: day, count: 200)
    SearchTrend.create!(tag: "beta", day: day, count: 200) # same count as alpha, should rank by tag name
    SearchTrend.create!(tag: "gamma", day: day, count: 50)

    ranked_results = SearchTrend.for_day_ranked(day)

    assert_equal 4, ranked_results.count

    # Verify ranking: count DESC, tag ASC
    expected_order = [
      ["alpha", 200, 1],  # count 200, alphabetically first
      ["beta", 200, 2],   # count 200, alphabetically second
      ["zebra", 100, 3],  # count 100
      ["gamma", 50, 4],   # count 50
    ]

    ranked_results.each_with_index do |trend, i|
      expected_tag, expected_count, expected_rank = expected_order[i]
      assert_equal expected_tag, trend.tag
      assert_equal expected_count, trend.count
      assert_equal expected_rank, trend.daily_rank
    end
  end

  test "for_day_ranked preserves ranks when combined with search" do
    day = Time.now.utc.to_date - 3

    # Create test data
    SearchTrend.create!(tag: "wolf", day: day, count: 100)     # rank 1
    SearchTrend.create!(tag: "fox", day: day, count: 80)       # rank 2
    SearchTrend.create!(tag: "cat", day: day, count: 60)       # rank 3
    SearchTrend.create!(tag: "dog", day: day, count: 40)       # rank 4

    # Search for tags containing 'o' (wolf, fox, dog) - should preserve original ranks
    filtered_results = SearchTrend.for_day_ranked(day).where_ilike(:tag, "*o*")

    assert_equal 3, filtered_results.count

    # Verify original ranks are preserved even though results are filtered
    filtered_results.each do |trend|
      case trend.tag
      when "wolf"
        assert_equal 1, trend.daily_rank
      when "fox"
        assert_equal 2, trend.daily_rank
      when "dog"
        assert_equal 4, trend.daily_rank
      end
    end
  end

  # --- record_query! ---

  test "record_query! records plain tags" do
    SearchTrendHourly.record_query!("cat dog")
    tags = SearchTrendHourly.for_day(Time.now.utc.to_date).pluck(:tag)
    assert_includes tags, "cat"
    assert_includes tags, "dog"
  end

  test "record_query! strips the ~ prefix and records the tag" do
    SearchTrendHourly.record_query!("~wolf")
    assert SearchTrendHourly.for_day(Time.now.utc.to_date).where(tag: "wolf").exists?
  end

  test "record_query! excludes tags with the - prefix" do
    SearchTrendHourly.record_query!("-fox")
    assert_not SearchTrendHourly.for_day(Time.now.utc.to_date).where(tag: "fox").exists?
  end

  test "record_query! excludes tags with a ~- compound prefix" do
    SearchTrendHourly.record_query!("~-cat")
    assert_not SearchTrendHourly.for_day(Time.now.utc.to_date).where(tag: "cat").exists?
  end

  test "record_query! handles a mixed query correctly" do
    SearchTrendHourly.record_query!("cat ~dog -fox ~-bird")
    tags = SearchTrendHourly.for_day(Time.now.utc.to_date).pluck(:tag)
    assert_includes     tags, "cat"
    assert_includes     tags, "dog"   # ~ stripped
    assert_not_includes tags, "fox"   # - excluded
    assert_not_includes tags, "bird"  # ~- excluded
  end

  test "record_query! excludes all tags inside a negated group" do
    SearchTrendHourly.record_query!("-( cat dog )")
    tags = SearchTrendHourly.for_day(Time.now.utc.to_date).pluck(:tag)
    assert_not_includes tags, "cat"
    assert_not_includes tags, "dog"
  end

  test "record_query! records tags from a ~ group without prefix" do
    SearchTrendHourly.record_query!("~( cat dog )")
    tags = SearchTrendHourly.for_day(Time.now.utc.to_date).pluck(:tag)
    assert_includes tags, "cat"
    assert_includes tags, "dog"
  end

  test "record_query! excludes tags inside a doubly-negated group" do
    SearchTrendHourly.record_query!("-( ~( cat ) )")
    assert_not SearchTrendHourly.for_day(Time.now.utc.to_date).where(tag: "cat").exists?
  end

  test "record_query! skips metatags" do
    SearchTrendHourly.record_query!("cat rating:s score:>10")
    tags = SearchTrendHourly.for_day(Time.now.utc.to_date).pluck(:tag)
    assert_includes     tags, "cat"
    assert_not_includes tags, "rating:s"
    assert_not_includes tags, "score:>10"
  end

  test "record_query! does nothing for a blank query" do
    assert_no_difference -> { SearchTrendHourly.count } do
      SearchTrendHourly.record_query!(nil)
      SearchTrendHourly.record_query!("")
      SearchTrendHourly.record_query!("   ")
    end
  end

  test "record_query! swallows errors and does not raise" do
    # Pass an object whose #blank? returns false but causes scan_recursive to blow up.
    bad_query = Object.new
    def bad_query.blank? = false
    assert_nothing_raised { SearchTrendHourly.record_query!(bad_query) }
  end
end
