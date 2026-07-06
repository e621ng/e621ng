# frozen_string_literal: true

module Fixes
  class FixPostScoresFromLockedVotes
    def self.run
      # Due to incorrect score calculations, all posts that had negative votes
      # locked (set to score = 0) have incorrect `down_score` value.

      Post.without_timeout do
        processed = 0
        fixed = 0

        Post.joins(:votes).where(votes: { score: 0 }).distinct.find_each do |post|
          processed += 1
          down_score = 0 - post.votes.where("score < 0").count
          puts "Processed #{processed} posts, fixed #{fixed} posts" if processed % 1000 == 0

          next if post.down_score == down_score
          fixed += 1

          post.update_columns(down_score: down_score)
          post.update_index
        end

        puts "Processed #{processed} posts, fixed #{fixed} posts"
      end
    end
  end
end

Fixes::FixPostScoresFromLockedVotes.run
