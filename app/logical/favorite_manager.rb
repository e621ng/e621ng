# frozen_string_literal: true

class FavoriteManager
  ISOLATION = Rails.env.test? ? {} : { isolation: :repeatable_read }

  # Add a favorite for the given user and post.
  # @param user [User] The user adding the favorite
  # @param post [Post] The post being favorited
  # @param force [Boolean] Whether to bypass favorite limit checking (default: false)
  # @raises [Favorite::Error] When user has reached favorite limit, already favorited, or post save fails
  # @raises [ActiveRecord::SerializationFailure] When transaction conflicts cannot be resolved
  def self.add!(user:, post:, force: false)
    retries = 5
    begin
      Favorite.transaction(**ISOLATION) do
        if !force && (user.favorite_count >= user.favorite_limit)
          raise Favorite::Error, "You can only keep up to #{user.favorite_limit} favorites."
        end

        Favorite.create(user_id: user.id, post_id: post.id)
        post.append_user_to_fav_string(user.id)
        post.do_not_version_changes = true

        raise Favorite::Error, "Failed to update post: #{post.errors.full_messages.join(', ')}" unless post.save
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      if retries > 0
        post.reload # Re-attempt with fresh post data
        retry
      end
      raise e
    rescue ActiveRecord::RecordNotUnique
      return if force

      Favorite.transaction(**ISOLATION) do
        raise Favorite::Error, "You have already favorited this post" if post.favorited_by?(user.id)

        # Handle an orphaned favorite record
        post.append_user_to_fav_string(user.id)
        post.do_not_version_changes = true
        raise Favorite::Error, "Failed to update post: #{post.errors.full_messages.join(', ')}" unless post.save
      end
    end
  end

  # Remove a favorite for the given user and post.
  # @param user [User] The user removing the favorite
  # @param post [Post] The post being unfavorited
  # @raises [Favorite::Error] When post save fails after favorite removal
  # @raises [ActiveRecord::SerializationFailure] When transaction conflicts cannot be resolved
  def self.remove!(user:, post:)
    retries = 5
    begin
      Favorite.transaction(**ISOLATION) do
        Favorite.for_user(user.id).where(post_id: post.id).destroy_all
        post.delete_user_from_fav_string(user.id)
        post.do_not_version_changes = true

        raise Favorite::Error, "Failed to update post: #{post.errors.full_messages.join(', ')}" unless post.save
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      if retries > 0
        post.reload # Re-attempt with fresh post data
        retry
      end
      raise e
    end
  end
end
