class VoteManager
  def self.vote!(user:, post:, score:)
    @vote = nil
    retries = 5
    score = score.to_i
    begin
      raise PostVote::Error.new("Invalid vote") unless [1, -1].include?(score)
      raise PostVote::Error.new("You do not have permission to vote") unless user.is_voter?
      target_isolation = !Rails.env.test? ? { isolation: :serializable } : {}
      PostVote.transaction(**target_isolation) do
        PostVote.uncached do
          post.with_lock do
            score_modifier = score
            old_vote = PostVote.where(user_id: user.id, post_id: post.id).first
            if old_vote
              raise PostVote::Error.new("Vote is locked") if old_vote.score == 0
              if old_vote.score == score
                return :need_unvote
              else
                score_modifier *= 2
              end
              old_vote.destroy
            end
            @vote = vote = PostVote.create!(user: user, score: score, post: post)
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
        end
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      retry if retries > 0
      raise e
    rescue ActiveRecord::RecordNotUnique
      raise PostVote::Error.new("You have already voted for this post")
    end
    post.update_index
    @vote
  end

  def self.unvote!(user:, post:, force: false)
    retries = 5
    begin
      target_isolation = !Rails.env.test? ? { isolation: :serializable } : {}
      PostVote.transaction(**target_isolation) do
        PostVote.uncached do
          post.with_lock do
            vote = PostVote.where(user_id: user.id, post_id: post.id).first
            return unless vote
            raise PostVote::Error.new "You can't remove locked votes" if vote.score == 0 && !force
            post.votes.where(user: user).delete_all
            subtract_vote(post, vote)
            post.reload
          end
        end
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      retry if retries > 0
      raise e
    end
    post.update_index
  end

  def self.lock!(id)
    post = nil
    target_isolation = !Rails.env.test? ? { isolation: :serializable } : {}
    PostVote.transaction(**target_isolation) do
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
    retries = 5
    @vote = nil
    score = score.to_i
    begin
      raise CommentVote::Error.new("Invalid vote") unless [1, -1].include?(score)
      raise CommentVote::Error.new("You do not have permission to vote") unless user.is_voter?
      target_isolation = !Rails.env.test? ? { isolation: :serializable } : {}
      CommentVote.transaction(**target_isolation) do
        CommentVote.uncached do
          comment.with_lock do
            score_modifier = score
            old_vote = CommentVote.where(user_id: user.id, comment_id: comment.id).first
            if old_vote
              raise CommentVote::Error.new("Vote is locked") if old_vote.score == 0
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
      end
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      retry if retries > 0
      raise e
    rescue ActiveRecord::RecordNotUnique
      raise CommentVote::Error.new("You have already voted for this post")
    end
    @vote
  end

  def self.comment_unvote!(user:, comment:, force: false)
    target_isolation = !Rails.env.test? ? { isolation: :serializable } : {}
    CommentVote.transaction(**target_isolation) do
      CommentVote.uncached do
        comment.with_lock do
          vote = CommentVote.where(user_id: user.id, comment_id: comment.id).first
          return unless vote
          raise CommentVote::Error.new("You can't remove locked votes") if vote.score == 0 && !force
          CommentVote.where(user_id: user.id, comment_id: comment.id).delete_all
          Comment.where(id: comment.id).update_all("score = score - #{vote.score}")
        end
      end
    end
  end

  def self.comment_lock!(id)
    target_isolation = !Rails.env.test? ? { isolation: :serializable } : {}
    CommentVote.transaction(**target_isolation) do
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
