# frozen_string_literal: true

module Fixes
  class FixPostScoresFromLockedVotes
    def self.run
      # Due to incorrect score calculations, all posts that had negative votes locked (set to score = 0)
      # have incorrect total scores. This fix will recalculate the scores for all posts that have locked votes.

      Post.without_timeout do
        # Find posts with at least one locked vote (score = 0) and recalculate their scores
        Post.joins(:votes).where(votes: { score: 0 }).distinct.find_each do |post|
          # Recalculate the scores for the post
          up_score = post.votes.where("score > 0").count
          down_score = post.votes.where("score < 0").count
          total_score = up_score - down_score

          # Update the post's scores
          post.update_columns(score: total_score, up_score: up_score, down_score: down_score)

          # Update hotness and index for the post
          post.update_hotness!
          post.update_index
        end
      end
    end
  end
end

Fixes::FixPostScoresFromLockedVotes.run
