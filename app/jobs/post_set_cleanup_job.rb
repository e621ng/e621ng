# frozen_string_literal: true

# Cleans up denormalized post state after a pool is destroyed.
class PostSetCleanupJob < ApplicationJob
  sidekiq_options queue: "default", lock: :until_executing, lock_ttl: 1.hour.to_i

  def perform(type, obj_id)
    case type.to_sym
    when :pool
      cleanup_pool(obj_id)
    when :set
      # Legacy: sets no longer keep post-side DB state; PostSet#enqueue_destroy_cleanup
      # now reindexes members directly. This branch only serves jobs that were already
      # enqueued when that change was deployed.
      # TODO: delete this branch (and rename the job) when pool_string is dropped.
      reindex_legacy_set_members(obj_id)
    else
      raise ArgumentError, "Invalid type: #{type.inspect}"
    end
  end

  private

  # Scoped on posts.pool_ids rather than the destroyed pool's post_ids snapshot,
  # so any post that still claims membership is cleaned even if the two drifted.
  def cleanup_pool(pool_id)
    stub = Struct.new(:id).new(pool_id)
    scope = Post.where("pool_ids @> ARRAY[?]::int[]", pool_id)

    # Pools check for whether the user account is older than 7 days.
    CurrentUser.as_system do
      scope.find_in_batches(batch_size: 1000) do |batch|
        Post.transaction do
          batch.each do |post|
            post.remove_pool!(stub)
            post.save!
          end
        end
      end
    end
  end

  # The pool_string column still exists in the DB during the transition (it is
  # merely ignored by ActiveRecord), so its token index can still locate the
  # destroyed set's members for reindexing.
  def reindex_legacy_set_members(set_id)
    ids = Post.where("string_to_array(pool_string, ' ') @> ARRAY[?]::text[]", "set:#{set_id}").pluck(:id)
    ids.each_slice(5_000) { |slice| BulkIndexUpdateJob.perform_async("Post", slice) }
  end
end
