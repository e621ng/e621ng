# frozen_string_literal: true

module Populate
  class PostVotes < Base
    def call
      count = options.fetch(:count, 0)
      return unless count > 0
      log "* Generating post votes"

      users = options.fetch(:users, [])
      users = random_users if users.empty?
      posts = options.fetch(:posts, [])
      posts = random_posts(limit: 100) if posts.empty?

      count.times do
        CurrentUser.user = users.sample
        post = posts.sample

        vote = VoteManager.vote!(
          user: CurrentUser.user,
          post: post,
          score: Faker::Boolean.boolean(true_ratio: 0.2) ? -1 : 1,
        )

        if vote == :need_unvote
          log "    error: #{vote}"
        else
          log "    vote ##{vote.id} on post ##{post.id}"
        end
      end
    end
  end
end
