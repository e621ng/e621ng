# frozen_string_literal: true

class VoteManager
  ISOLATION = Rails.env.test? ? {} : { isolation: :repeatable_read }

  # ============================== #
  # ========= Post Votes ========= #
  # ============================== #

  def self.vote!(user:, post:, score:)
    @vote = nil
    score = score.to_i
    raise UserVote::Error, "Invalid vote" unless [1, -1].include?(score)
    raise UserVote::Error, "You do not have permission to vote" unless user.is_member?

    result = PostVote.transaction do
      post.lock!
      post.reload

      old_vote = PostVote.where(user_id: user.id, post_id: post.id).first

      if old_vote
        raise UserVote::Error, "Vote is locked" if old_vote.score == 0
        next :need_unvote if old_vote.score == score
        old_vote.destroy
      end

      @vote = PostVote.create!(user: user, score: score, post: post)

      # If replacing an opposite vote, the change is doubled
      score_delta = old_vote ? score * 2 : score
      vote_cols = ["score = score + #{score_delta}"]

      if score > 0
        vote_cols << "up_score = up_score + 1"
        vote_cols << "down_score = down_score - 1" if old_vote
      else
        vote_cols << "down_score = down_score + 1"
        vote_cols << "up_score = up_score - 1" if old_vote
      end
      Post.where(id: post.id).update_all(vote_cols.join(", "))

      post.reload
      @vote
    end

    post.update_index if result != :need_unvote
    result
  rescue ActiveRecord::RecordNotUnique
    raise UserVote::Error, "You have already voted for this post"
  end

  def self.unvote!(user:, post:, force: false)
    did_unvote = PostVote.transaction do
      post.lock!
      post.reload

      vote = PostVote.where(user_id: user.id, post_id: post.id).first # Query after acquiring lock to prevent deadlocks
      next false unless vote
      raise UserVote::Error, "You can't remove locked votes" if vote.score == 0 && !force

      post.votes.where(user: user).delete_all # Delete after acquiring lock to prevent deadlocks

      vote_cols = ["score = score - #{vote.score}"]
      if vote.score > 0
        vote_cols << "up_score = up_score - 1"
      else
        vote_cols << "down_score = down_score - 1"
      end
      Post.where(id: post.id).update_all(vote_cols.join(", "))

      post.reload
      true
    end

    post.update_index if did_unvote
  end

  def self.lock!(id)
    post = PostVote.transaction do
      vote = PostVote.find_by(id: id)
      next nil unless vote
      post = vote.post
      post.lock!
      post.reload

      vote_cols = ["score = score - #{vote.score}"]
      if vote.score > 0
        vote_cols << "up_score = up_score - 1"
      else
        vote_cols << "down_score = down_score - 1"
      end
      Post.where(id: post.id).update_all(vote_cols.join(", "))

      vote.update_column(:score, 0)
      post
    end
    post&.update_index
  end

  def self.admin_unvote!(id)
    vote = PostVote.find_by(id: id)
    unvote!(post: vote.post, user: vote.user, force: true) if vote
  end

  # ============================== #
  # ======== Comment Votes ======= #
  # ============================== #

  def self.comment_vote!(user:, comment:, score:)
    retries = 5
    @vote = nil
    score = score.to_i
    begin
      raise UserVote::Error, "Invalid vote" unless [1, -1].include?(score)
      raise UserVote::Error, "You do not have permission to vote" unless user.is_member?
      raise UserVote::Error, "Comment section is locked" if comment.post.is_comment_locked?
      raise UserVote::Error, "Comment section is disabled" if comment.post.is_comment_disabled?
      CommentVote.transaction(**ISOLATION) do
        CommentVote.uncached do
          score_modifier = score
          old_vote = CommentVote.where(user_id: user.id, comment_id: comment.id).first
          if old_vote
            raise UserVote::Error.new("Vote is locked") if old_vote.score == 0
            if old_vote.score == score
              return :need_unvote
            else
              score_modifier *= 2
            end
            old_vote.destroy
          end
          @vote = CommentVote.create!(user_id: user.id, score: score, comment_id: comment.id)
          Comment.where(id: comment.id).update_all("score = score + #{score_modifier}")
        end
      end
    rescue ActiveRecord::SerializationFailure
      retries -= 1
      retry if retries > 0
      raise UserVote::Error.new("Failed to vote, please try again later.")
    rescue ActiveRecord::RecordNotUnique
      raise UserVote::Error.new("You have already voted for this comment")
    end
    @vote
  end

  def self.comment_unvote!(user:, comment:, force: false)
    CommentVote.transaction(**ISOLATION) do
      CommentVote.uncached do
        vote = CommentVote.where(user_id: user.id, comment_id: comment.id).first
        return unless vote
        raise UserVote::Error.new("You can't remove locked votes") if vote.score == 0 && !force
        CommentVote.where(user_id: user.id, comment_id: comment.id).delete_all
        Comment.where(id: comment.id).update_all("score = score - #{vote.score}")
      end
    end
  end

  def self.comment_lock!(id)
    CommentVote.transaction(**ISOLATION) do
      vote = CommentVote.find_by(id: id)
      return unless vote
      comment = vote.comment
      Comment.where(id: comment.id).update_all("score = score - #{vote.score}")
      vote.update_column(:score, 0)
    end
  end

  def self.admin_comment_unvote!(id)
    vote = CommentVote.find_by(id: id)
    comment_unvote!(comment: vote.comment, user: vote.user, force: true) if vote
  end
end
