# frozen_string_literal: true

# This job is used to remove all of the user's favorites.
# It is intended to be run when a user is deleted or when they request to clear their favorites.
class FlushFavoritesJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    user = User.find(args[0])

    Thread.current[:skip_post_index_update] = true

    Favorite.without_timeout do
      Favorite.for_user(user.id).select(:id, :post_id).find_in_batches(batch_size: 10_000) do |batch|
        ids = batch.map(&:post_id)
        Favorite.where(id: batch.map(&:id)).delete_all
        Post.without_timeout do
          Post.where(id: ids).update_all("fav_count = fav_count - 1")
        end
        BulkIndexUpdateJob.perform_later("Post", ids)
      end
    end

    UserStatus.for_user(user.id).update_all("favorite_count = 0")
  ensure
    Thread.current[:skip_post_index_update] = false
  end
end
