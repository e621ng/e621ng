# frozen_string_literal: true

class SearchTrendAggregateJob < ApplicationJob
  queue_as :default

  def perform
    aggregate_unprocessed_records!
  end

  private

  # Aggregate all unprocessed hourly records into daily totals and mark them as processed.
  # Only processes records older than 1 hour to avoid race conditions with active search operations.
  # Uses batched processing with proper locking to prevent concurrent modification issues.
  def aggregate_unprocessed_records!
    # Establish cutoff time - only process records older than 1 hour (UTC)
    cutoff_time = 1.hour.ago.utc.beginning_of_hour

    # Quick check if there are any candidates
    return if SearchTrendHourly.unprocessed_before(cutoff_time).empty?

    batch_size = 100
    total_processed = 0
    start_time = Time.current.utc

    # Use repeatable read isolation to prevent phantom reads during processing
    isolation_level = Rails.env.test? ? {} : { isolation: :repeatable_read }

    # Find all unprocessed records within our time window and group by tag, day
    # Use timezone('UTC', hour) to ensure date extraction is in UTC regardless of database timezone
    unprocessed_groups = SearchTrendHourly.unprocessed_before(cutoff_time)
                                          .group(:tag, "DATE(timezone('UTC', hour))")
                                          .sum(:count)

    # Process groups in batches to minimize lock time
    unprocessed_groups.each_slice(batch_size).with_index do |batch_groups, batch_index|
      SearchTrend.transaction(**isolation_level) do
        batch_processed = 0

        batch_groups.each do |(tag, day), total_count|
          # Lock and aggregate the specific hourly records for this tag/day combination
          hourly_records = SearchTrendHourly.unprocessed_before(cutoff_time)
                                            .where(tag: tag)
                                            .where("DATE(timezone('UTC', hour)) = ?", day)
                                            .lock("FOR UPDATE")
                                            .to_a

          # Skip if no records found (may have been processed by concurrent job)
          next if hourly_records.empty?

          # Verify the locked records sum matches our expected total
          actual_total = hourly_records.sum(&:count)
          if actual_total != total_count
            Rails.logger.warn("SearchTrendAggregateJob: Count mismatch for #{tag}/#{day}: expected #{total_count}, got #{actual_total}")
            # Use the actual locked total to ensure accuracy
            total_count = actual_total
          end

          # Update or create the daily aggregate record
          daily_record = SearchTrend.find_or_initialize_by(tag: tag, day: day)
          daily_record.count = (daily_record.count || 0) + total_count
          daily_record.save!

          # Mark only the locked hourly records as processed
          SearchTrendHourly.where(id: hourly_records.map(&:id))
                           .update_all(processed: true, updated_at: Time.current.utc)

          batch_processed += 1
        end

        total_processed += batch_processed
        Rails.logger.debug { "SearchTrendAggregateJob: Batch #{batch_index + 1} processed #{batch_processed} tag/day combinations" }
      end
    end

    elapsed_time = Time.current.utc - start_time
    Rails.logger.info("SearchTrendAggregateJob: Processed #{total_processed} tag/day combinations in #{elapsed_time.round(2)}s (cutoff: #{cutoff_time})")
  end
end
