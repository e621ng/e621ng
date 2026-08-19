# frozen_string_literal: true

# Legacy: pool_string set tokens are no longer maintained. Kept for one release
# so jobs enqueued before that deploy still resolve; it reindexes both the set's
# current members (covers pending adds) and any posts whose still-extant
# pool_string tokens reference the set (covers pending removals).
# TODO: delete together with the pool_string column drop.
class PostSetPostsSyncJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing, lock_args_method: :lock_args

  def self.lock_args(args)
    [args.first]
  end

  def perform(set_id)
    ids = PostSet.find(set_id).post_ids
    ids |= Post.where("string_to_array(pool_string, ' ') @> ARRAY[?]::text[]", "set:#{set_id}").pluck(:id)
    ids.each_slice(5_000) { |slice| BulkIndexUpdateJob.perform_later("Post", slice) }
  rescue ActiveRecord::RecordNotFound
    # Set was deleted; the destroy path reindexed its members.
  end
end
