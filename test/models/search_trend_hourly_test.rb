# frozen_string_literal: true

require "test_helper"

class SearchTrendHourlyTest < ActiveSupport::TestCase
  context "search trend hourly" do
    setup do
      Setting.trends_enabled = true
      @trend = SearchTrendHourly.create!(tag: "test", hour: 1.hour.ago.utc.beginning_of_hour, count: 5)
    end

    teardown do
      Setting.trends_enabled = false
    end

    should "validate required fields" do
      trend = SearchTrendHourly.new
      assert_not trend.valid?
      assert_includes trend.errors[:tag], "can't be blank"
      assert_includes trend.errors[:hour], "can't be blank"
    end

    should "validate uniqueness of tag and hour" do
      duplicate_trend = SearchTrendHourly.new(tag: @trend.tag, hour: @trend.hour)
      assert_not duplicate_trend.valid?
      assert_includes duplicate_trend.errors[:hour], "has already been taken"
    end

    should "default processed to false" do
      new_trend = SearchTrendHourly.create!(tag: "new", hour: 2.hours.ago.utc.beginning_of_hour, count: 3)
      assert_equal false, new_trend.processed
    end

    context "#bulk_increment!" do
      should "create new record if it doesn't exist" do
        hour = 3.hours.ago.utc.beginning_of_hour

        assert_difference("SearchTrendHourly.count", 1) do
          SearchTrendHourly.bulk_increment!([{ tag: "newtag", hour: hour }])
        end

        trend = SearchTrendHourly.find_by(tag: "newtag", hour: hour)
        assert_equal 1, trend.count
        assert_equal false, trend.processed
      end

      should "increment existing record" do
        hour = 4.hours.ago.utc.beginning_of_hour # Ensure we use beginning of hour
        existing = SearchTrendHourly.create!(tag: "existing", hour: hour, count: 5)

        assert_no_difference("SearchTrendHourly.count") do
          SearchTrendHourly.bulk_increment!([{ tag: "existing", hour: hour }])
        end

        existing.reload
        assert_equal 6, existing.count
      end

      should "handle multiple tag-hour pairs efficiently" do
        hour1 = 1.hour.ago.utc.beginning_of_hour
        hour2 = 2.hours.ago.utc.beginning_of_hour

        data = [
          { tag: "bulk1", hour: hour1 },
          { tag: "bulk2", hour: hour1 },
          { tag: "bulk1", hour: hour2 },
        ]

        assert_difference("SearchTrendHourly.count", 3) do
          SearchTrendHourly.bulk_increment!(data)
        end

        assert_equal 1, SearchTrendHourly.find_by(tag: "bulk1", hour: hour1).count
        assert_equal 1, SearchTrendHourly.find_by(tag: "bulk2", hour: hour1).count
        assert_equal 1, SearchTrendHourly.find_by(tag: "bulk1", hour: hour2).count
      end
    end

    context "scopes" do
      setup do
        @processed = SearchTrendHourly.create!(tag: "processed", hour: 5.hours.ago.utc.beginning_of_hour, count: 3, processed: true)
        @unprocessed = SearchTrendHourly.create!(tag: "unprocessed", hour: 6.hours.ago.utc.beginning_of_hour, count: 2, processed: false)
      end

      context ".unprocessed" do
        should "return only unprocessed trends" do
          results = SearchTrendHourly.unprocessed
          assert_includes results, @unprocessed
          assert_not_includes results, @processed
        end
      end

      context ".processed" do
        should "return only processed trends" do
          results = SearchTrendHourly.processed
          assert_includes results, @processed
          assert_not_includes results, @unprocessed
        end
      end
    end

    context "#prune!" do
      should "remove old processed records but keep recent and unprocessed ones" do
        old_hour = 3.days.ago.utc      # More than 48 hours ago
        recent_hour = 1.hour.ago.utc   # Less than 48 hours ago

        # Old processed records (should be deleted)
        old_processed1 = SearchTrendHourly.create!(tag: "owl", hour: old_hour, count: 10, processed: true)
        old_processed2 = SearchTrendHourly.create!(tag: "owl", hour: old_hour + 1.hour, count: 15, processed: true)

        # Old unprocessed records (should be kept)
        old_unprocessed = SearchTrendHourly.create!(tag: "rabbit", hour: old_hour, count: 5, processed: false)

        # Recent processed records (should be kept)
        recent_processed = SearchTrendHourly.create!(tag: "cat", hour: recent_hour, count: 3, processed: true)

        SearchTrendHourly.prune!

        # Old processed records should be deleted
        assert_not SearchTrendHourly.exists?(old_processed1.id)
        assert_not SearchTrendHourly.exists?(old_processed2.id)

        # Old unprocessed and recent records should remain
        assert SearchTrendHourly.exists?(old_unprocessed.id)
        assert SearchTrendHourly.exists?(recent_processed.id)
      end

      should "only remove old processed hourly records" do
        old_hour = 3.days.ago.utc
        recent_hour = 1.hour.ago.utc

        # Create some processed and unprocessed hourly records
        old_processed = SearchTrendHourly.create!(tag: "old", hour: old_hour, count: 10, processed: true)
        old_unprocessed = SearchTrendHourly.create!(tag: "oldunproc", hour: old_hour, count: 5, processed: false)
        recent_processed = SearchTrendHourly.create!(tag: "recent", hour: recent_hour, count: 20, processed: true)
        recent_unprocessed = SearchTrendHourly.create!(tag: "recentunproc", hour: recent_hour, count: 15, processed: false)

        SearchTrendHourly.prune!

        # Only old processed records should be deleted
        assert_not SearchTrendHourly.exists?(old_processed.id)
        assert SearchTrendHourly.exists?(old_unprocessed.id) # Keep unprocessed
        assert SearchTrendHourly.exists?(recent_processed.id) # Keep recent
        assert SearchTrendHourly.exists?(recent_unprocessed.id) # Keep recent
      end
    end
  end
end
