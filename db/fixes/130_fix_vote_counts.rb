# frozen_string_literal: true

# Recalculates vote counts for posts that have had votes in the past 24 hours
module Fixes
  class FixVoteCounts
    def self.run
      PostVote.without_timeout do
        puts "Finding posts with votes in the past 24 hours..."

        # Get unique post IDs that have had votes in the past 24 hours
        post_ids = PostVote.where("created_at >= ?", 24.hours.ago)
                           .distinct
                           .pluck(:post_id)

        puts "Found #{post_ids.size} posts to recalculate"

        return if post_ids.empty?

        # Process posts in batches to avoid memory issues
        processed = 0
        post_ids.each_slice(100) do |batch_ids|
          Post.where(id: batch_ids).find_each do |post|
            recalculate_post_scores(post)
            processed += 1
            print "\rProcessed #{processed}/#{post_ids.size} posts" if processed % 10 == 0
          end
        end

        puts "\nDone! Recalculated scores for #{processed} posts"
      end
    end

    def self.recalculate_post_scores(post)
      # Count up and down votes (excluding locked votes with score 0)
      up_votes = PostVote.where(post_id: post.id, score: 1).count
      down_votes = PostVote.where(post_id: post.id, score: -1).count
      total_score = up_votes - down_votes

      # Update the post directly without triggering callbacks
      Post.where(id: post.id).update_all(
        score: total_score,
        up_score: up_votes,
        down_score: 0 - down_votes,
      )

      # Update search index if needed
      post.reload
      post.update_index
    rescue StandardError => e
      puts "\nError processing post #{post.id}: #{e.message}"
    end

    private_class_method :recalculate_post_scores
  end
end

# Run the fix
Fixes::FixVoteCounts.run
