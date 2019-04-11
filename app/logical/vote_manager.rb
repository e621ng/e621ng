class VoteManager
  def self.vote!(user:, post:, score:)
    @vote = nil
    score = score_modifier = score.to_i
    # TODO retry on ActiveRecord::TransactionIsloationConflict?
    begin
      raise PostVote::Error.new("Invalid vote") unless [1, -1].include?(score)
      raise PostVote::Error.new("You do not have permission to vote") unless user.is_voter?
      PostVote.transaction(isolation: :serializable) do
        old_vote = post.votes.where(user_id: user.id).first
        if old_vote
          raise PostVote::Error.new("Vote is locked") if old_vote.score == 0
          if old_vote.score == score
            return :need_unvote
          else
            score_modifier *= 2
          end
          old_vote.destroy
        end
        @vote = vote = post.votes.create!(user: user, score: score)
        vote_cols = "score = score + #{score_modifier}"
        if vote.score > 0
          vote_cols += ", up_score = up_score + #{vote.score}"
          vote_cols += ", down_score = down_score - #{old_vote.score}" if old_vote
        else
          vote_cols += ", down_score = down_score + #{vote.score}"
          vote_cols += ", up_score = up_score - #{old_vote.score}" if old_vote
        end
        Post.where(id: post.id).update_all(vote_cols)
        post.reload
      end
      post.update_index
    rescue ActiveRecord::RecordNotUnique
      raise PostVote::Error.new("You have already voted for this post")
    end
    @vote
  end

  def self.unvote!(user:, post:, force: false)
    PostVote.transaction(isolation: :serializable) do
      vote = post.votes.where(user: user).first
      return unless vote
      raise PostVote::Error.new "You can't remove locked votes" if vote.score == 0 && !force
      post.votes.where(user: user).delete_all
      subtract_vote(post, vote)
      post.reload
    end
    post.update_index
  end

  def self.lock!(id)
    post = nil
    PostVote.transaction(isolation: :serializable) do
      vote = PostVote.find_by(id: id)
      return unless vote
      post = vote.post
      subtract_vote(post, vote)
      vote.update_column(:score, 0)
    end
    post.update_index if post
  end

  def self.admin_unvote!(id)
    vote = PostVote.find_by(id: id)
    unvote!(post: vote.post, user: vote.user, force: true) if vote
  end

  def self.comment_vote!(user:, comment:, score:)
    @vote = nil
    # TODO retry on ActiveRecord::TransactionIsloationConflict?
    score = score_modifier = score.to_i
    begin
      raise CommentVote::Error.new("Invalid vote") unless [1, -1].include?(score)
      raise CommentVote::Error.new("You do not have permission to vote") unless user.is_voter?
      CommentVote.transaction(isolation: :serializable) do
        old_vote = comment.votes.where(user_id: user.id).first
        if old_vote
          raise CommentVote::Error.new("Vote is locked") if old_vote.score == 0
          if old_vote.score == score
            return :need_unvote
          else
            score_modifier *= 2
          end
          old_vote.destroy
        end
        @vote = comment.votes.create!(user: user, score: score)
        Comment.where(id: comment.id).update_all("score = score + #{score_modifier}")
      end
    rescue ActiveRecord::RecordNotUnique
      raise CommentVote::Error.new("You have already voted for this post")
    end
    @vote
  end

  def self.comment_unvote!(user:, comment:, force: false)
    CommentVote.transaction(isolation: :serializable) do
      vote = comment.votes.where(user: user).first
      return unless vote
      raise CommentVote::Error.new("You can't remove locked votes") if vote.score == 0 && !force
      comment.votes.where(user: user).delete_all
      Comment.where(id: comment.id).update_all("score = score - #{vote.score}")
    end
  end

  def self.comment_lock!(id)
    CommentVote.transaction(isolation: :serializable) do
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

  private

  def self.subtract_vote(post, vote)
    vote_cols = "score = score - #{vote.score}"
    if vote.score > 0
      vote_cols += ", up_score = up_score - #{vote.score}"
    else
      vote_cols += ", down_score = down_score - #{vote.score}"
    end
    Post.where(id: post.id).update_all(vote_cols)
  end
end