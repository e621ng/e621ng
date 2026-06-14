# frozen_string_literal: true

class VoteTrends
  RatingTrendTag = Struct.new(:name, :post_count, :uploader_id, :uploader, keyword_init: true)

  def self.vote_abuse_patterns(user:, limit: 10, threshold: 0.0001, duration: nil, vote_normality: true)
    return if limit > Danbooru.config.post_vote_limit # safety: Use the hourly vote limiy to prevent this query from being too expensive
    # Create a KV pair of tags/uploader keys and their weighted vote counts
    tag_votes = Hash.new(0)
    uploader_ids = Set.new
    scope = user.post_votes.includes(:post).order(updated_at: :desc)

    votes = scope.limit(limit).to_a

    if duration
      days = duration.is_a?(String) ? duration.to_f : duration
      if days > 0
        time_ago = days.days.ago
        votes = votes.select { |v| v.updated_at >= time_ago }
      end
    end

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

      if post.uploader_id.present?
        key = "uploader:!#{post.uploader_id}"
        tag_votes[key] += weight
        uploader_ids << post.uploader_id
      end

      if post.rating.present?
        tag_votes["rating:#{post.rating}"] += weight
      end
    end

    # weight tags by their total usage over the whole site
    tag_records = Tag.where(name: tag_votes.keys).index_by(&:name)

    uploader_post_counts = {}
    if uploader_ids.any?
      Post.where(uploader_id: uploader_ids.to_a).group(:uploader_id).count.each do |uid, cnt|
        uploader_post_counts[uid.to_i] = cnt
      end
    end

    tag_post_counts = tag_votes.keys.index_with do |tag_name|
      if tag_records[tag_name]
        tag_records[tag_name].post_count
      elsif tag_name.match?(/^rating:[sqe]$/)
        Post.tag_match(tag_name, always_show_deleted: true).count_only
      elsif tag_name =~ /^uploader:!(\d+)$/
        uid = $1.to_i
        uploader_post_counts[uid] || 0
      else
        0
      end
    end

    tag_votes.each_key do |tag|
      tag_votes[tag] /= tag_post_counts[tag].to_f unless tag_post_counts[tag].to_i == 0
    end

    # Sort the tags by their absolute vote counts and return the top N
    users_by_id = User.where(id: uploader_ids.to_a).index_by(&:id)

    tag_votes.select { |_, count| count.abs > threshold }
             .sort_by { |_, count| count }
             .map { |tag_name, count| [trend_tag_for(tag_name, tag_records, users_by_id, uploader_post_counts), count] }
  end

  def self.calculate_vote_weight(vote, post, vote_normality: true)
    tag_count = post.tag_count
    return 0 unless tag_count && tag_count > 0
    # Calculate the score ratio of the posts
    up_score = post.up_score.to_f
    down_score = post.down_score.to_f
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

  def self.trend_tag_for(tag_name, tag_records, users_by_id = {}, uploader_post_counts = {})
    return tag_records[tag_name] if tag_records.key?(tag_name)

    if tag_name =~ /^uploader:!(\d+)$/
      uid = $1.to_i
      user = users_by_id[uid]
      display_name = user ? "uploader:#{user.name}" : "uploader:!#{uid}"
      return RatingTrendTag.new(name: display_name, post_count: uploader_post_counts[uid] || 0, uploader_id: uid, uploader: user)
    end

    RatingTrendTag.new(name: tag_name, post_count: 0)
  end
end
