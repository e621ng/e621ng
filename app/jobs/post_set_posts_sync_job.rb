# frozen_string_literal: true

class PostSetPostsSyncJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing, lock_args_method: :lock_args

  def self.lock_args(args)
    [args.first]
  end

  def perform(set_id)
    set = PostSet.find(set_id)

    current_ids = set.post_ids.to_set
    synced_ids  = Post.where("set_ids @> ARRAY[?]::bigint[]", set_id).pluck(:id).to_set

    to_add    = (current_ids - synced_ids).to_a
    to_remove = (synced_ids - current_ids).to_a
    return if to_add.empty? && to_remove.empty?

    pg = Post.connection.raw_connection

    if to_add.any?
      pg.exec_params(
        "UPDATE posts
         SET set_ids = array_append(set_ids, $1::bigint)
         WHERE id = ANY($2::int[])
           AND NOT ($1::bigint = ANY(set_ids))",
        [set_id, "{#{to_add.join(',')}}"],
      )
    end

    if to_remove.any?
      pg.exec_params(
        "UPDATE posts
         SET set_ids = array_remove(set_ids, $1::bigint)
         WHERE id = ANY($2::int[])
           AND $1::bigint = ANY(set_ids)",
        [set_id, "{#{to_remove.join(',')}}"],
      )
    end

    BulkIndexUpdateJob.perform_later("Post", to_add + to_remove)
  rescue ActiveRecord::RecordNotFound
    # Set was deleted; nothing to do.
  end
end
