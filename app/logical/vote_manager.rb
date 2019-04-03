class VoteManager
  def self.vote!(user:, post:, score: "locked")
    begin
      PostVote.transaction(isolation: :serializable) do
        unless user.is_voter?
          raise PostVote::Error.new("You do not have permission to vote")
        end

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

  def self.unvote!(user:, post:)
    PostVote.transaction(isolation: :serializable) do
      vote = post.votes.where(user: user).first
      return unless vote
      post.votes.where(user: user).delete_all
      vote_cols = "score = score - #{vote.score}"
      if vote.score > 0
        vote_cols += ", up_score = up_score - #{vote.score}"
      else
        vote_cols += ", down_score = down_score - #{vote.score}"
      end
      Post.where(id: post.id).update_all(vote_cols)
      post.reload
    end
    post.update_index
  end
end