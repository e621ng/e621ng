# frozen_string_literal: true

module DangerZone
  def self.uploads_disabled?(user)
    user.level < min_upload_level
  end

  def self.post_visible?(post, user)
    if hide_pending_posts_for <= 0
      return true
    end

    post.uploader_id == user.id || user.is_staff? || !post.is_pending? || post.created_at.before?(hide_pending_posts_for.hours.ago)
  end

  def self.min_upload_level
    (Cache.redis.get("min_upload_level") || User::Levels::MEMBER).to_i
  rescue Redis::CannotConnectError
    User::Levels::ADMIN + 1
  end

  def self.min_upload_level=(min_upload_level)
    Cache.redis.set("min_upload_level", min_upload_level)
  end

  def self.hide_pending_posts_for
    Cache.redis.get("hide_pending_posts_for").to_f || 0
  rescue Redis::CannotConnectError
    PostPruner::DELETION_WINDOW * 24
  end

  def self.hide_pending_posts_for=(duration)
    Cache.redis.set("hide_pending_posts_for", duration)
  end
end
