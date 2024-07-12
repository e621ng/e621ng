#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

class PostEventTemp < PostEvent
  self.table_name = "post_events_temp"
end

ActiveRecord::Base.connection.execute('CREATE TABLE post_events_temp (
	id bigserial NOT NULL,
	creator_id int8 NOT NULL,
	post_id int8 NOT NULL,
	"action" int4 NOT NULL,
	extra_data jsonb NOT NULL,
	created_at timestamp NOT NULL,
	CONSTRAINT post_events_temp_pkey PRIMARY KEY (id)
);')

ActiveRecord::Base.connection.execute('CREATE INDEX index_post_events_temp_on_created_at ON public.post_events_temp USING btree (created_at);')

def create(post_id, creator_id, created_at, action, extra_data = {})
  PostEventTemp.create!(post_id: post_id, creator_id: creator_id, created_at: created_at, action: action, extra_data: extra_data)
end

PostApproval.find_in_batches do |batch|
  batch.pluck(:user_id, :post_id, :created_at).each do |approval|
    creator_id, post_id, created_at = approval
    create(post_id, creator_id, created_at, :approved)
  end
end

PostFlag.find_in_batches do |batch|
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
PostEvent.without_timeout do
  ActiveRecord::Base.connection.execute('INSERT INTO post_events (creator_id, post_id, "action", extra_data, created_at)
    SELECT creator_id, post_id, "action", extra_data, created_at FROM post_events_temp ORDER BY created_at ASC;')
end
# ActiveRecord::Base.connection.execute('DROP TABLE post_events_temp;')
