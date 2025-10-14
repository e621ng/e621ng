# frozen_string_literal: true

class PostSetCleanupJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  # Remove the set tag from all posts that referenced this set in pool_string.
  def perform(set_id)
    tag = "set:#{set_id}"
    scope = Post.where("string_to_array(pool_string, ' ') @> ARRAY[?]::text[]", tag)
    scope.find_in_batches(batch_size: 1000) do |batch|
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
