# frozen_string_literal: true

module Populate
  class Avatars < Base
    def call
      users = options.fetch(:users, [])
      return if users.empty?
      log "* Filling in #{users.size} avatars"

      posts = options.fetch(:posts, [])
      posts = random_posts(limit: users.size).select(&:has_preview?) if posts.empty?
      return if posts.empty?

      users.each do |user|
        post = posts.sample
        log "  - #{user.name} : ##{post.id}"
        user.update(avatar_id: post.id)
      end
    end
  end
end
