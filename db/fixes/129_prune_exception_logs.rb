#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# Manually prune old ExceptionLog records in batches.
#
# Environment variables:
# - CUTOFF_DAYS: number of days to keep (default: 365)
# - BATCH_SIZE: number of rows per batch delete (default: 10000)
# - DRY_RUN: set to "1" to only count rows without deleting (default: 0)
# - PAUSE_MS: sleep between batches in milliseconds (default: 0)
# - LOCK_TIMEOUT_MS: lock timeout per statement in milliseconds (default: unset)

cutoff_days     = ENV.fetch("CUTOFF_DAYS", "365").to_i
batch_size      = ENV.fetch("BATCH_SIZE", "10000").to_i
dry_run         = ENV["DRY_RUN"] == "1"
pause_ms        = ENV.fetch("PAUSE_MS", "0").to_i
lock_timeout_ms = ENV["LOCK_TIMEOUT_MS"]&.to_i

cutoff = cutoff_days.days.ago

puts "Pruning ExceptionLog records older than #{cutoff_days} days (created before #{cutoff.utc})"
puts "Batch size: #{batch_size} | Dry run: #{dry_run ? 'ON' : 'OFF'} | Pause: #{pause_ms}ms | Lock timeout: #{lock_timeout_ms || 'default'}"

ExceptionLog.without_timeout do # rubocop:disable Metrics/BlockLength
  scope = ExceptionLog.where("created_at < ?", cutoff)

  total_before = begin
    scope.count
  rescue StandardError
    nil
  end

  puts "Total matching records: #{total_before.nil? ? 'unknown' : total_before}"

  # Cap scanning to only relevant rows by finding the highest id within the cutoff.
  # This avoids iterating through empty id ranges beyond the cutoff set.
  max_id = scope.maximum(:id)
  if max_id.nil?
    puts "No records to prune."
    exit(0)
  end

  total = 0
  index = 0
  last_id = 0

  loop do
    ids = ExceptionLog
          .where("id > ? AND id <= ? AND created_at < ?", last_id, max_id, cutoff)
          .order(:id)
          .limit(batch_size)
          .pluck(:id)

    break if ids.empty?

    deleted = if dry_run
                ids.size
              elsif lock_timeout_ms && lock_timeout_ms > 0
                # Apply an optional per-statement lock timeout to be a good citizen under load.
                ActiveRecord::Base.transaction do
                  ActiveRecord::Base.connection.execute("SET LOCAL lock_timeout = '#{lock_timeout_ms}ms'")
                  ExceptionLog.where(id: ids).delete_all
                end
              else
                ExceptionLog.where(id: ids).delete_all
              end

    total += deleted
    last_id = ids.last
    puts "batch #{index} #{dry_run ? 'would delete' : 'deleted'} #{deleted} (total #{total})"
    index += 1

    sleep(pause_ms / 1000.0) if pause_ms > 0
  end

  summary = dry_run ? "Would delete" : "Deleted"
  puts "#{summary} #{total} ExceptionLog records older than #{cutoff_days} days."
end
