#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

PostReplacement.where(uploader_id_on_approve: nil).where.not(status: "original").find_in_batches(batch_size: 10_000) do |batch|
  next if batch.empty?
  updates = []
  batch.pluck(:id, :post_id).each do |replacement_id, post_id|
    previous = PostReplacement.where(post_id: post_id) # replacements for the same post
                              .where("(status = 'approved' AND id < ?) OR status = 'original'", replacement_id) # approved before this one, or the original
                              .order("updated_at DESC").limit(1).first # get the last replacement before this one
    if previous.present? && previous.creator_id.present?
      updates << { post_id: post_id, uploader_id_on_approve: previous.creator_id }
    end
  end

  updates.each do |update|
    PostReplacement.where(
      post_id: update[:post_id],
      uploader_id_on_approve: nil,
    ).where.not(status: "original").update_all(uploader_id_on_approve: update[:uploader_on_approve])
  end
end

PostReplacement.where(approver_id: nil, status: "original").find_in_batches(batch_size: 10_000) do |batch|
  next if batch.empty?

  updates = []

  batch.pluck(:post_id, :created_at).each do |post_id, created_at|
    event = PostEvent.where(post_id: post_id, action: :approved)
                     .where("created_at < ?", created_at) # that took place before the replacement was created
                     .order(created_at: :desc).limit(1).first # get the last event before the replacement was created
    valid_event = event.present? && event.creator_id.present?
    updates << { post_id: post_id, approver_id: event.creator_id } if valid_event
  end

  updates.each do |update|
    PostReplacement.where(
      post_id: update[:post_id],
      approver_id: nil,
      status: "original",
    ).update_all(approver_id: update[:approver_id])
  end
end
