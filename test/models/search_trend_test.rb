# frozen_string_literal: true

require "test_helper"

class SearchTrendTest < ActiveSupport::TestCase
  test "increment! creates and increments counts" do
    assert_difference -> { SearchTrend.count }, +1 do
      SearchTrend.increment!("Test_Tag")
    end
    rec = SearchTrend.find_by(tag: "test_tag", day: Date.current)
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

  test "rising returns tags with substantial day-over-day increase ordered by today's count" do
    today = Date.current
    yesterday = today - 1

    # Not enough today
    SearchTrend.create!(tag: "low", day: today, count: 5)

    # Delta-based inclusion (30 - 10 >= 10)
    SearchTrend.create!(tag: "foo", day: yesterday, count: 10)
    SearchTrend.create!(tag: "foo", day: today, count: 30)

    # Ratio-based inclusion (12 / 5 >= 2.0) but delta 7 < 10
    SearchTrend.create!(tag: "ratio", day: yesterday, count: 5)
    SearchTrend.create!(tag: "ratio", day: today, count: 12)

    # Included by delta (15 - 0 >= 10)
    SearchTrend.create!(tag: "baz", day: today, count: 15)

    # Not included (25-20 < 10 and 25/20 < 2)
    SearchTrend.create!(tag: "bar", day: yesterday, count: 20)
    SearchTrend.create!(tag: "bar", day: today, count: 25)

    rising = SearchTrend.rising(day: today, limit: 10)
    assert_equal %w[foo baz ratio], rising.pluck(:tag)
  end
end
