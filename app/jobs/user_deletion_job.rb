# frozen_string_literal: true

class UserDeletionJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    user = User.find(args[0])

    remove_favorites(user)
  end

  def remove_favorites(user)
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
