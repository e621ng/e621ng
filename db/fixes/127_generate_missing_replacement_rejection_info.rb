#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

PostReplacement.where(approver_id: nil, status: "rejected").find_in_batches(batch_size: 10_000) do |batch|
  next if batch.empty?

  updates = []

  batch.each do |replacement|
    event = PostEvent.where(
      action: "replacement_rejected",
    ).where(
      "extra_data ->> 'replacement_id' = ?", replacement.id.to_s
    ).order(created_at: :desc).first

    if event&.creator_id.present?
      updates << { id: replacement.id, approver_id: event.creator_id }
    end
  end

  updates.each do |update|
    PostReplacement.where(
      id: update[:id],
      approver_id: nil,
      status: "rejected",
    ).update_all(approver_id: update[:approver_id])
  end
end
