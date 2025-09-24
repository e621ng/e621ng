# frozen_string_literal: true

module Security
  module Lockdown
    # Panic
    def self.uploads_disabled?
      Setting.uploads_disabled?
    end

    def self.uploads_disabled=(state)
      Setting.uploads_disabled = state == "1"
    end

    def self.pools_disabled?
      Setting.pools_disabled?
    end

    def self.pools_disabled=(state)
      Setting.pools_disabled = state == "1"
    end

    def self.post_sets_disabled?
      Setting.post_sets_disabled?
    end

    def self.post_sets_disabled=(state)
      Setting.post_sets_disabled = state == "1"
    end

    def self.comments_disabled?
      Setting.comments_disabled?
    end

    def self.comments_disabled=(state)
      Setting.comments_disabled = state == "1"
    end

    def self.forums_disabled?
      Setting.forums_disabled?
    end

    def self.forums_disabled=(state)
      Setting.forums_disabled = state == "1"
    end

    def self.blips_disabled?
      Setting.blips_disabled?
    end

    def self.blips_disabled=(state)
      Setting.blips_disabled = state == "1"
    end

    def self.aiburs_disabled?
      Setting.aiburs_disabled?
    end

    def self.aiburs_disabled=(state)
      Setting.aiburs_disabled = state == "1"
    end

    def self.favorites_disabled?
      Setting.favorites_disabled?
    end

    def self.favorites_disabled=(state)
      Setting.favorites_disabled = state == "1"
    end

    def self.votes_disabled?
      Setting.votes_disabled?
    end

    def self.votes_disabled=(state)
      Setting.votes_disabled = state == "1"
    end

    # Uploader level override
    def self.uploads_min_level
      Setting.uploads_min_level
    end

    def self.uploads_min_level=(min_upload_level)
      Setting.uploads_min_level = min_upload_level
    end

    # Hiding pending posts
    def self.hide_pending_posts_for
      Setting.hide_pending_posts_for
    end

    def self.hide_pending_posts_for=(duration)
      Setting.hide_pending_posts_for = duration
    end

    def self.post_visible?(post, user)
      if hide_pending_posts_for <= 0
        return true
      end

      post.uploader_id == user.id || user.is_staff? || !post.is_pending? || post.created_at.before?(hide_pending_posts_for.hours.ago)
    end
  end
end
