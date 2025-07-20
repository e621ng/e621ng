# frozen_string_literal: true

# This job is used to remove all of the user's favorites.
# It is intended to be run when a user is deleted or when they request to clear their favorites.
class FlushFavoritesJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    user = User.find(args[0])

    Favorite.without_timeout do
      Favorite.for_user(user.id).includes(:post).find_each do |fav|
        tries = 5
        begin
          FavoriteManager.remove!(user: user, post: fav.post)
        rescue ActiveRecord::SerializationFailure
          tries -= 1
          retry if tries > 0
        end
      end
    end
  end
end
