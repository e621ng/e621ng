# frozen_string_literal: true

module Populate
  class CommentVotes < Base
    def call
      count = options.fetch(:count, 0)
      return unless count > 0
      log "* Generating comment votes"

      users = options.fetch(:users, [])
      users = random_users if users.empty?
      comments = options.fetch(:comments, [])
      comments = Comment.limit(100).order("random()") if comments.empty?

      count.times do
        CurrentUser.user = users.sample
        comment = comments.sample

        if comment.creator_id == CurrentUser.user.id
          log "    error: can't vote on your own comment"
          next
        elsif comment.is_sticky?
          log "    error: can't vote on a sticky comment"
          next
        end

        vote = VoteManager.comment_vote!(
          user: CurrentUser.user,
          comment: comment,
          score: Faker::Boolean.boolean(true_ratio: 0.2) ? -1 : 1,
        )

        if vote == :need_unvote
          log "    error: #{vote}"
        else
          log "    vote ##{vote.id} on comment ##{comment.id}"
        end
      end
    end
  end
end
