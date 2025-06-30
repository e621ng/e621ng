# frozen_string_literal: true

class VoteManager
  ISOLATION = Rails.env.test? ? {} : { isolation: :repeatable_read }

  def self.vote!(user:, post:, score:)
    @vote = nil
    retries = 5
    score = score.to_i
    begin
      raise UserVote::Error.new("Invalid vote") unless [1, -1].include?(score)
      raise UserVote::Error.new("You do not have permission to vote") unless user.is_member?
      PostVote.transaction(**ISOLATION) do
        PostVote.uncached do
          score_modifier = score
          old_vote = PostVote.where(user_id: user.id, post_id: post.id).first
          if old_vote
            raise UserVote::Error.new("Vote is locked") if old_vote.score == 0
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
    rescue ActiveRecord::SerializationFailure => e
      retries -= 1
      retry if retries > 0
      raise UserVote::Error.new("Failed to vote, please try again later")
    rescue ActiveRecord::RecordNotUnique
      raise UserVote::Error.new("You have already voted for this post")
    end
    post.update_index
    @vote
  end

  def self.unvote!(user:, post:, force: false)
    retries = 5
    begin
      PostVote.transaction(**ISOLATION) do
        PostVote.uncached do
          vote = PostVote.where(user_id: user.id, post_id: post.id).first
          return unless vote
          raise UserVote::Error.new "You can't remove locked votes" if vote.score == 0 && !force
          post.votes.where(user: user).delete_all
          subtract_vote(post, vote)
          post.reload
        end
      end
    rescue ActiveRecord::SerializationFailure
      retries -= 1
      retry if retries > 0
      raise UserVote::Error.new("Failed to unvote, please try again later")
    end
    post.update_index
  end

  def self.lock!(id)
    post = nil
    PostVote.transaction(**ISOLATION) do
      vote = PostVote.find_by(id: id)
      return unless vote
      post = vote.post
      subtract_vote(post, vote)
      vote.update_column(:score, 0)
    end
    post&.update_index
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

  module VoteAbuseMethods
    # methods related to vote abuse detection and prevention

    # Section: Vote Abuse Detection
    # - Dectect users who vote on many posts in a short time period.

    # Section: Vote Patterns
    # look for patterns in votes: 
    # - make an KV pair using posts the user has recently voted on. 
    #   - Key: Each unique tag on the posts
    #   - Value: Running total of the number of votes for that tag. Each vote is weighted:
    #     - Weight by how much the vote 'agrees' with the post's score ratio. This can be ignored if the post has few votes.
    #     - Weight by how many total tags the post has.
    # - Weight each tag by the total usage of the tag (tag count). Tag.post_count is available on the tag model. 
    # - Sort the KV pair by the absolute value of the value, and return the top N tags. Only return tags that have a value above a certain threshold.
    # **Large values indicate the user is voting up on posts with that tag, and small values indicate the user is voting down on posts with that tag.**
    def self.vote_abuse_patterns(user, limit: 10, threshold: 0.0001)
      # return [] unless user.is_member?
      # return [] unless user.post_votes.exists?

      # Create a KV pair of tags and their weighted vote counts
      tag_votes = Hash.new(0)
      user.post_votes.order(updated_at: :desc).limit(limit).each do |vote|
        post = vote.post
        next unless post

        post.tags.each do |tag|
          weight = calculate_vote_weight(vote, post)
          #puts "Tag: #{tag.name}, Weight: #{'%02.05f'%(weight*1000)}"  # for debugging purposes, remove this line in production
          tag_votes[tag] += weight
        end
        # return
        # tag_votes = tag_votes.sort_by { |_, count| -count.abs }.to_h
        # tag_votes.each do |tag, count| puts "Tag: #{tag.name}, Count: #{'%2.010f'%count}" end
        # return # for debugging purposes, remove this line in production
      end
      # weight tags by their total usage over the whole site
      tag_votes.each do |tag, count|
        # puts "Tag: #{tag.name}, Count: #{'%2.02f'%count}, Total Posts: #{tag.post_count}"
        tag_votes[tag] /= tag.post_count.to_f # if tag.post_count && tag.post_count != 0
      end
      # Sort the tags by their absolute vote counts and return the top N
      result = tag_votes.select { |_, count| count.abs > threshold }
            .sort_by { |_, count| -count.abs }
            .to_h

      result.each do |tag, freq| puts "#{tag.name}  \t#{'%02.05f'% freq}" end
    end

    def self.calculate_vote_weight(vote, post)
      # Calculate the weight of the vote based on the post's score ratio and total tags
      # Weight magnitude is based on the post's score ratio and the number of tags on the post (and how the user votes according to the ratio)
      # negative value means the user is voting down on posts with that tag, positive value means the user is voting up on posts with that tag
      tag_count = post.tag_count_general + post.tag_count_artist + post.tag_count_contributor + post.tag_count_copyright 
                + post.tag_count_character + post.tag_count_species + post.tag_count_meta + post.tag_count_lore + post.tag_count_invalid 
      return 0 unless tag_count && tag_count > 0
      # Calculate the score ratio of the post
      up_score = post.up_score.to_f
      down_score = post.down_score.to_f || 0.0
      total_score = up_score + down_score
      score_ratio = total_score != 0 ? (up_score-down_score) / total_score : 1.0
      # Calculate the weight based on the user's vote and the post's score ratio
      weight = vote.score * (score_ratio / tag_count.to_f)
      weight 
    end
  end
include VoteAbuseMethods
end
