# frozen_string_literal: true

module UserAvatarUrlCache
  CACHE_TTL = 15.minutes

  def self.key(user_id)
    "user_avatar_url:#{user_id}"
  end

  # Returns the JPEG URL for the navbar avatar, or nil if unavailable.
  # For cropped avatars, computes inline with no query. For uncropped avatars,
  # caches the post's preview URL to avoid loading the full post on every request.
  def self.get(user)
    return nil if user.blank? || user.avatar_id.blank?

    if user.has_cropped_avatar?
      [
        "/data/avatars/#{user.id}.webp?t=#{user.updated_at.to_i}",
        "/data/avatars/#{user.id}.jpg?t=#{user.updated_at.to_i}",
      ]
    else
      Cache.fetch(key(user.id), expires_in: CACHE_TTL) do
        post = Post.find_by(id: user.avatar_id)
        # NOTE: For deleted posts, this will cache nil, which is what we want.
        # Deleted posts cannot be used as avatars, and this will prevent repeated lookups.
        post && !post.is_deleted? ? post.preview_file_url_pair : nil
      end
    end
  end

  def self.invalidate(user_id)
    Cache.delete(key(user_id))
  end
end
