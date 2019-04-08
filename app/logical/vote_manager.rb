class VoteManager
  def self.vote!(user:, post:, score: "locked")
    # TODO retry on ActiveRecord::TransactionisloationConflict?
    begin
      unless user.is_voter?
        raise PostVote::Error.new("You do not have permission to vote")
      end
      PostVote.transaction(isolation: :serializable) do
        vote = post.votes.create!(user: user, vote: score)
        vote_cols = "score = score + #{vote.score}"
        if vote.score > 0
          vote_cols += ", up_score = up_score + #{vote.score}"
        else
          vote_cols += ", down_score = down_score + #{vote.score}"
        end
        Post.where(id: post.id).update_all(vote_cols)
        post.reload
      end
      post.update_index
    rescue ActiveRecord::RecordNotUnique
      raise PostVote::Error.new("You have already voted for this post")
    end
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
    # TODO retry on ActiveRecord::TransactionisloationConflict?
    score = score_modifier = score.to_i
    begin
      unless [1, -1].include?(score)
        raise CommentVote::Error.new("Invalid vote")
      end
      unless user.is_voter?
        raise CommentVote::Error.new("You do not have permission to vote")
      end
      CommentVote.transaction(isolation: :serializable) do
        old_vote = comment.votes.where(user_id: user.id).first
        if old_vote
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