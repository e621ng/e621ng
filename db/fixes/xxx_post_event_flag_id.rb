#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))
PostFlag.find_in_batches(batch_size: 10_000) do |batch|
  next if batch.empty?

  updated = 0
  batch.each do |flag|
    begin
      next unless flag.post_id && flag.created_at

      # look for PostEvent records for the same post that are either flag_created or deleted
      # and that occurred close in time to the flag (use a 5 minute window)
      window = 5.minutes
      events = PostEvent.where(post_id: flag.post_id)
                        .where(action: %w[flag_created deleted])
                        .where("created_at >= ? AND created_at <= ?", flag.created_at - window, flag.created_at + window)

      next if events.empty?

      # pick the nearest event which contains a reason in extra_data but doesn't already have a flag_id
      candidates = events.select do |e|
        ed = e.extra_data
        ed.is_a?(Hash) && ed.key?("reason") && !ed.key?("flag_id")
      end

      next if candidates.empty?

      event = candidates.min_by { |e| (e.created_at - flag.created_at).abs }

      next if event.extra_data&.key?("flag_id") # skip if already linked

      # overwrite extra_data with the canonical flag reference (or print in DRY_RUN)
      if ENV['DRY_RUN']
        puts "DRY_RUN: would update PostEvent id=#{event.id} (post_id=#{event.post_id}) to flag_id=#{flag.id}"
      else
        event.update_column(:extra_data, { "flag_id" => flag.id })
      end
      updated += 1
    rescue => e
      puts "ERROR processing PostFlag id=#{flag.id}: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      next
    end
  end

  puts "Processed batch: #{batch.first.id}-#{batch.last.id}, updated #{updated} PostEvent(s)"
end

puts "Done."
