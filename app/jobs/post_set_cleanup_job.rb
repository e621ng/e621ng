# frozen_string_literal: true

class PostSetCleanupJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  # Remove the set tag from all posts that referenced this set in pool_string.
  # We can’t rely on PostSet.post_ids after destroy, so we search by pool_string.
  def perform(set_id)
    tag = "set:#{set_id}"
    # Find affected posts in batches
    Post.where("pool_string ~ ?", "(^|\\s)#{Regexp.escape(tag)}(\\s|$)").find_in_batches(batch_size: 1000) do |batch|
      Post.transaction do
        batch.each do |post|
          # Use model method to keep callbacks/indexing consistent
          set_stub = Struct.new(:id).new(set_id)
          post.remove_set!(set_stub)
          post.save!
        end
      end
    end
  end
end
