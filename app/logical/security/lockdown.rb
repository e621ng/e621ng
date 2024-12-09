# frozen_string_literal: true

module Security
  module Lockdown
    # Panic
    def self.uploads_disabled?
      Cache.redis.get("uploads_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.uploads_disabled=(state)
      Cache.redis.set("uploads_disabled", state == "1")
    end

    def self.pools_disabled?
      Cache.redis.get("pools_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.pools_disabled=(state)
      Cache.redis.set("pools_disabled", state == "1")
    end

    def self.post_sets_disabled?
      Cache.redis.get("post_sets_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.post_sets_disabled=(state)
      Cache.redis.set("post_sets_disabled", state == "1")
    end

    def self.comments_disabled?
      Cache.redis.get("comments_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.comments_disabled=(state)
      Cache.redis.set("comments_disabled", state == "1")
    end

    def self.forums_disabled?
      Cache.redis.get("forums_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.forums_disabled=(state)
      Cache.redis.set("forums_disabled", state == "1")
    end

    def self.blips_disabled?
      Cache.redis.get("blips_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.blips_disabled=(state)
      Cache.redis.set("blips_disabled", state == "1")
    end

    def self.aiburs_disabled?
      Cache.redis.get("aiburs_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.aiburs_disabled=(state)
      Cache.redis.set("aiburs_disabled", state == "1")
    end

    def self.favorites_disabled?
      Cache.redis.get("favorites_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.favorites_disabled=(state)
      Cache.redis.set("favorites_disabled", state == "1")
    end

    def self.votes_disabled?
      Cache.redis.get("votes_disabled") == "true"
    rescue Redis::CannotConnectError
      true
    end

    def self.votes_disabled=(state)
      Cache.redis.set("votes_disabled", state == "1")
    end

    # Uploader level override
    def self.uploads_min_level
      (Cache.redis.get("min_upload_level") || User::Levels::MEMBER).to_i
    rescue Redis::CannotConnectError
      User::Levels::ADMIN + 1
    end

    def self.uploads_min_level=(min_upload_level)
      Cache.redis.set("min_upload_level", min_upload_level)
    end

    # Hiding pending posts
    def self.hide_pending_posts_for
      Cache.redis.get("hide_pending_posts_for").to_f || 0
    rescue Redis::CannotConnectError
      PostPruner::DELETION_WINDOW * 24
    end

    def self.hide_pending_posts_for=(duration)
      Cache.redis.set("hide_pending_posts_for", duration)
    end

    def self.post_visible?(post, user)
      if hide_pending_posts_for <= 0
        return true
      end

      post.uploader_id == user.id || user.is_staff? || !post.is_pending? || post.created_at.before?(hide_pending_posts_for.hours.ago)
    end
  end
end
