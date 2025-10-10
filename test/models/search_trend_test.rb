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
end
