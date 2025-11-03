# frozen_string_literal: true

class FavoriteManager
  # Add a favorite for the given user and post.
  # @param user [User] The user adding the favorite
  # @param post [Post] The post being favorited
  # @param force [Boolean] Whether to bypass favorite limit checking (default: false)
  # @raises [Favorite::Error] When user has reached favorite limit, already favorited, or post save fails
  # @raises [ActiveRecord::SerializationFailure] When transaction conflicts cannot be resolved
  def self.add!(user:, post:, force: false)
    Favorite.transaction do
      if !force && (user.favorite_count >= user.favorite_limit)
        raise Favorite::Error, "You can only keep up to #{user.favorite_limit} favorites."
      end

      Favorite.create(user_id: user.id, post_id: post.id)

      post.lock!
      post.reload
      post.append_user_to_fav_string(user.id)
      post.do_not_version_changes = true

      raise Favorite::Error, "Failed to update post: #{post.errors.full_messages.join(', ')}" unless post.save
    end
  rescue ActiveRecord::RecordNotUnique
    return if force
    raise Favorite::Error, "You have already favorited this post" if post.favorited_by?(user.id)

    # Handle orphaned favorite record
    Favorite.transaction do
      post.lock!
      post.reload
      post.append_user_to_fav_string(user.id)
      post.do_not_version_changes = true

      raise Favorite::Error, "Failed to update post: #{post.errors.full_messages.join(', ')}" unless post.save
    end
  end

  # Remove a favorite for the given user and post.
  # @param user [User] The user removing the favorite
  # @param post [Post] The post being unfavorited
  # @raises [Favorite::Error] When post save fails after favorite removal
  # @raises [ActiveRecord::SerializationFailure] When transaction conflicts cannot be resolved
  def self.remove!(user:, post:)
    Favorite.transaction do
      Favorite.for_user(user.id).where(post_id: post.id).destroy_all

      post.lock!
      post.reload
      post.delete_user_from_fav_string(user.id)
      post.do_not_version_changes = true

      raise Favorite::Error, "Failed to update post: #{post.errors.full_messages.join(', ')}" unless post.save
    end
  end
end
