# frozen_string_literal: true

module Populate
  class Comments < Base
    def call
      count = options.fetch(:count, 0)
      return [] unless count > 0
      log "* Creating #{count} comments"
      output = []

      users = options.fetch(:users, [])
      users = random_users if users.empty?
      posts = random_posts

      count.times do
        post = posts.sample
        CurrentUser.user = users.sample

        comment = Comment.create do |c|
          c.creator = CurrentUser.user
          c.updater = CurrentUser.user
          c.post = post
          c.body = paragraph
          c.creator_ip_addr = LOCAL_IP
        end

        log "  - ##{comment.id} by #{CurrentUser.user.name}"
        output << comment if comment.valid?
      end

      output
    end
  end
end
