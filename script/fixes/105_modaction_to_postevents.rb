#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

def create(post_id, creator_id, created_at, action, extra_data = {})
  PostEvent.create!(post_id: post_id, creator_id: creator_id, created_at: created_at, action: action, extra_data: extra_data)
end

PostApproval.in_batches do |batch|
  batch.pluck(:user_id, :post_id, :created_at).each do |approval|
    creator_id, post_id, created_at = approval
    create(post_id, creator_id, created_at, :approved)
  end
end

PostFlag.in_batches do |batch|
  batch.pluck(:creator_id, :post_id, :created_at, :is_deletion, :reason).each do |flag|
    creator_id, post_id, created_at, is_deletion, reason = flag
    if is_deletion
      create(post_id, creator_id, created_at, :deleted, { reason: reason })
    else
      create(post_id, creator_id, created_at, :flag_created, { reason: reason })
    end
  end
end

migrate_actions = %w[
  post_move_favorites
  post_undelete
  post_destroy
  post_rating_lock
  post_unapprove
  post_replacement_accept
  post_replacement_reject
  post_replacement_delete
]

ModAction.where(action: migrate_actions).in_batches do |batch|
  batch.pluck(:creator_id, :action, :values, :created_at).each do |modaction|
    creator_id, action, vals, created_at = modaction
    case action
    when "post_move_favorites"
      child_id = vals["post_id"]
      parent_id = vals["parent_id"]
      create(child_id, creator_id, created_at, :favorites_moved, { parent_id: parent_id })
      create(parent_id, creator_id, created_at, :favorites_received, { child_id: child_id })
    when "post_undelete"
      create(vals["post_id"], creator_id, created_at, :undeleted)
    when "post_destroy"
      create(vals["post_id"], creator_id, created_at, :expunged)
    when "post_rating_lock"
      action = vals['locked'] ? :rating_locked : :rating_unlocked
      create(vals["post_id"], creator_id, created_at, action)
    when "post_unapprove"
      create(vals["post_id"], creator_id, created_at, :unapproved)
    when "post_replacement_accept"
      create(vals["post_id"], creator_id, created_at, :replacement_accepted)
    when "post_replacement_reject"
      create(vals["post_id"], creator_id, created_at, :replacement_rejected)
    when "post_replacement_delete"
      create(vals["post_id"], creator_id, created_at, :replacement_deleted)
    end
  end
end
