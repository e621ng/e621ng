# frozen_string_literal: true

class FavoriteManager
  ISOLATION = Rails.env.test? ? {} : { isolation: :repeatable_read }

  def self.add!(user:, post:, force: false)
    retries = 5
    begin
      Favorite.transaction(**ISOLATION) do
        unless force
          if user.favorite_count >= user.favorite_limit
            raise Favorite::Error, "You can only keep up to #{user.favorite_limit} favorites."
          end
        end

        Favorite.create(:user_id => user.id, :post_id => post.id)
        post.append_user_to_fav_string(user.id)
        post.do_not_version_changes = true
        post.save
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      retry if retries > 0
      raise e
    rescue ActiveRecord::RecordNotUnique
      raise Favorite::Error, "You have already favorited this post" unless force
    end
  end

  def self.remove!(user:, post:)
    retries = 5
    begin
      Favorite.transaction(**ISOLATION) do
        unless Favorite.for_user(user.id).where(user_id: user.id, post_id: post.id).exists?
          return
        end

        Favorite.for_user(user.id).where(post_id: post.id).destroy_all
        post.delete_user_from_fav_string(user.id)
        post.do_not_version_changes = true
        post.save
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      retry if retries > 0
      raise e
    end
  end

  def self.give_to_parent!(post)
    # TODO Much better and more intelligent logic can exist for this
    parent = post.parent
    return false unless parent
    post.favorites.each do |fav|
      tries = 5
      begin
        FavoriteManager.remove!(user: fav.user, post: post)
        FavoriteManager.add!(user: fav.user, post: parent, force: true)
      rescue ActiveRecord::SerializationFailure
        tries -= 1
        retry if tries > 0
      end
    end
    true
  end
end
