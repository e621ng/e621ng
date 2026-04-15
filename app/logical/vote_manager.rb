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
        vote_cols << "down_score = down_score + 1" if old_vote
      else
        vote_cols << "down_score = down_score - 1"
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
        vote_cols << "down_score = down_score + 1"
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

  module VoteAbuseMethods
    RatingTrendTag = Struct.new(:name, :post_count, keyword_init: true)

    def self.vote_abuse_patterns(user:, limit: 10, threshold: 0.0001, duration: nil, vote_normality: true)
      # Create a KV pair of tags and their weighted vote counts
      tag_votes = Hash.new(0)
      scope = user.post_votes.includes(:post).order(updated_at: :desc)
      if duration
        time_ago =
          if duration.is_a?(String)
            duration.to_f.days.ago
          else
            duration.ago
          end
        scope = scope.where("updated_at >= ?", time_ago)
      end
      votes = scope.limit(limit).to_a
      posts = votes.filter_map(&:post)
      tags_by_name = Tag.where(name: posts.flat_map(&:tag_array).uniq).index_by(&:name)

      votes.each do |vote|
        post = vote.post
        next unless post

        weight = calculate_vote_weight(vote, post, vote_normality: vote_normality)

        post.tag_array.each do |tag_name|
          tag = tags_by_name[tag_name]
          next unless tag

          tag_votes[tag.name] += weight
        end

        if post.rating.present?
          tag_votes["rating:#{post.rating}"] += weight
        end
      end
      # weight tags by their total usage over the whole site
      tag_records = Tag.where(name: tag_votes.keys).index_by(&:name)
      rating_counts = rating_tag_names(tag_votes.keys).index_with do |tag_name|
        Post.tag_match(tag_name, always_show_deleted: true).count_only
      end

      tag_votes.each_key do |tag|
        tag_votes[tag] /= tag_count_for(tag, tag_records, rating_counts).to_f
      end
      # Sort the tags by their absolute vote counts and return the top N
      result = tag_votes.select { |_, count| count.abs > threshold } # rubocop:disable Style/RedundantAssignment
                        .sort_by { |_, count| -count.abs }
                        .to_h
                        .sort_by { |_, count| count }
                        .map { |tag_name, count| [trend_tag_for(tag_name, tag_records, rating_counts), count] }
      result
    end

    def self.calculate_vote_weight(vote, post, vote_normality: true)
      tag_count = post.tag_count
      return 0 unless tag_count && tag_count > 0
      # Calculate the score ratio of the posts
      up_score = post.up_score.to_f
      down_score = post.down_score.to_f || 0.0
      total_votes = up_score + down_score.abs # number of votes

      if vote_normality
        # ensure we don't divide by zero. Add up and down score in case of post.score cache
        score_ratio = total_votes == 0 ? 1.0 : (up_score + down_score).to_f / total_votes
      else
        score_ratio = 1.0
      end
      # Calculate the weight based on the user's vote and the post's score ratio
      vote.score * (score_ratio / tag_count.to_f)
    end

    def self.trend_tag_for(tag_name, tag_records, rating_counts)
      return tag_records[tag_name] if tag_records.key?(tag_name)

      RatingTrendTag.new(name: tag_name, post_count: rating_counts[tag_name])
    end

    def self.tag_count_for(tag_name, tag_records, rating_counts)
      tag_records[tag_name]&.post_count || rating_counts[tag_name]
    end

    def self.rating_tag_names(tag_names)
      tag_names.grep(/^rating:[sqe]$/)
    end
  end
end
