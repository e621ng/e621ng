# frozen_string_literal: true

require "test_helper"

class SearchTrendAggregateJobTest < ActiveJob::TestCase
  setup do
    Setting.trends_enabled = true
  end

  teardown do
    Setting.trends_enabled = false
  end

  should "process records older than 1 hour and ignore newer records" do
    # Create hourly records - some old, some new
    old_hour = 2.hours.ago.utc.beginning_of_hour
    new_hour = 30.minutes.ago.utc.beginning_of_hour

    old_record1 = SearchTrendHourly.create!(tag: "old_tag1", hour: old_hour, count: 5, processed: false)
    old_record2 = SearchTrendHourly.create!(tag: "old_tag2", hour: old_hour, count: 3, processed: false)
    new_record = SearchTrendHourly.create!(tag: "new_tag", hour: new_hour, count: 10, processed: false)

    # Run the aggregation job
    SearchTrendAggregateJob.perform_now

    # Check that old records were processed
    old_record1.reload
    old_record2.reload
    new_record.reload

    assert old_record1.processed, "Old record should be marked as processed"
    assert old_record2.processed, "Old record should be marked as processed"
    assert_not new_record.processed, "New record should NOT be marked as processed"

    # Check that daily aggregates were created for old records only
    old_day = old_hour.to_date
    new_day = new_hour.to_date

    assert SearchTrend.where(tag: "old_tag1", day: old_day).exists?, "Daily aggregate should exist for old_tag1"
    assert SearchTrend.where(tag: "old_tag2", day: old_day).exists?, "Daily aggregate should exist for old_tag2"
    assert_not SearchTrend.where(tag: "new_tag", day: new_day).exists?, "Daily aggregate should NOT exist for new_tag"

    # Verify the counts are correct
    assert_equal 5, SearchTrend.find_by(tag: "old_tag1", day: old_day).count
    assert_equal 3, SearchTrend.find_by(tag: "old_tag2", day: old_day).count
  end
end
