# frozen_string_literal: true

class PostSetPostsSyncJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing, lock_args_method: :lock_args

  def self.lock_args(args)
    [args.first]
  end

  def perform(set_id)
    set   = PostSet.find(set_id)
    token = "set:#{set_id}"

    current_ids = set.post_ids.to_set
    token_ids   = Post.where("string_to_array(pool_string, ' ') @> ARRAY[?]::text[]", token)
                      .pluck(:id).to_set

    to_add    = (current_ids - token_ids).to_a
    to_remove = (token_ids - current_ids).to_a
    return if to_add.empty? && to_remove.empty?

    pg = Post.connection.raw_connection

    if to_add.any?
      pg.exec_params(
        "UPDATE posts
         SET pool_string = trim(pool_string || $1)
         WHERE id = ANY($2::int[])
           AND NOT ($3 = ANY(string_to_array(pool_string, ' ')))",
        [" #{token}", "{#{to_add.join(',')}}", token],
      )
    end

    if to_remove.any?
      pg.exec_params(
        "UPDATE posts
         SET pool_string = array_to_string(
               array_remove(string_to_array(pool_string, ' '), $1), ' ')
         WHERE id = ANY($2::int[])
           AND $1 = ANY(string_to_array(pool_string, ' '))",
        [token, "{#{to_remove.join(',')}}"],
      )
    end

    BulkIndexUpdateJob.perform_later("Post", to_add + to_remove)
  rescue ActiveRecord::RecordNotFound
    # Set was deleted; nothing to do.
  end
end
