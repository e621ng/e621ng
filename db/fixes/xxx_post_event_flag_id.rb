#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

WINDOW   = 5.minutes
ACTIONS  = %w[flag_created deleted].freeze
DRY_RUN  = ENV.fetch("DRY_RUN", nil)
BATCH    = 10_000

def process_batch(batch)
  return if batch.empty?

  post_ids  = batch.map(&:post_id).uniq
  time_span = (batch.min_by(&:created_at).created_at - WINDOW)..(batch.max_by(&:created_at).created_at + WINDOW)

  events_by_post = PostEvent.where(post_id: post_ids, action: ACTIONS, created_at: time_span)
                            .select(:id, :post_id, :created_at, :extra_data)
                            .group_by(&:post_id)

  updates = []

  batch.each do |flag|
    candidates = events_by_post[flag.post_id]
    next unless candidates

    matching_events = candidates.select do |e|
      data = e.extra_data
      data.is_a?(Hash) && data.key?("reason") && !data.key?("flag_id")
    end

    event = matching_events.min_by do |e|
      (e.created_at - flag.created_at).abs
    end

    next unless event
    updates << [event.id, { "flag_id" => flag.id }]
  end

  updates.each do |event_id, data|
    if DRY_RUN
      puts "DRY_RUN: PostEvent id=#{event_id} -> #{data.inspect}"
    else
      PostEvent.where(id: event_id).update_all(extra_data: data) # skips callbacks/timestamps
    end
  end

  puts "Processed batch #{batch.first.id}-#{batch.last.id}, updated #{updates.size} PostEvent(s)"
end

PostFlag.where.not(post_id: nil, created_at: nil)
        .find_in_batches(batch_size: BATCH) do |batch|
  process_batch(batch)
end

puts "Done."
