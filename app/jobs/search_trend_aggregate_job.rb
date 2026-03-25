# frozen_string_literal: true

class SearchTrendAggregateJob < ApplicationJob
  queue_as :default

  def perform
    aggregate_unprocessed_records!
  end

  private

  # Aggregate all unprocessed hourly records into daily totals and mark them as processed
  def aggregate_unprocessed_records!
    return if SearchTrendHourly.unprocessed.empty?

    # Find all unprocessed records and group by tag and day (extracted from hour datetime)
    unprocessed_groups = SearchTrendHourly.unprocessed
                                          .group(:tag, "DATE(hour)")
                                          .sum(:count)

    # For each group, update or create the corresponding daily record
    unprocessed_groups.each do |(tag, day), total_count|
      SearchTrend.transaction do
        # Update or create the daily aggregate record
        daily_record = SearchTrend.find_or_initialize_by(tag: tag, day: day)
        daily_record.count = (daily_record.count || 0) + total_count
        daily_record.save!

        # Mark the hourly records as processed (filter by tag and day extracted from hour)
        SearchTrendHourly.unprocessed
                         .where(tag: tag)
                         .where("DATE(hour) = ?", day)
                         .update_all(processed: true, updated_at: Time.current)
      end
    end

    Rails.logger.info("SearchTrendAggregateJob: Processed #{unprocessed_groups.size} tag/day combinations")
  end
end
