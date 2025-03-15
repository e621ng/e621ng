# frozen_string_literal: true

class StatsUpdater
  def self.run!
    stats = {}
    stats[:started] = Post.find(Post.minimum("id")).created_at

    daily_average = ->(total) do
      (total / ((Time.now - stats[:started]) / (60 * 60 * 24))).round
    end

    ### Posts ###

    stats[:total_posts] = Post.maximum("id") || 0
    stats[:active_posts] = Post.tag_match("status:active").count_only
    stats[:deleted_posts] = Post.tag_match("status:deleted").count_only
    stats[:existing_posts] = stats[:active_posts] + stats[:deleted_posts]
    stats[:destroyed_posts] = stats[:total_posts] - stats[:existing_posts]
    stats[:total_votes] = PostVote.count
    stats[:total_notes] = Note.count
    stats[:total_favorites] = Favorite.count
    stats[:total_pools] = Pool.count
    stats[:public_sets] = PostSet.where(is_public: true).count
    stats[:private_sets] = PostSet.where(is_public: false).count
    stats[:total_sets] = stats[:public_sets] + stats[:private_sets]

    stats[:average_posts_per_pool] = Pool.average(Arel.sql("cardinality(post_ids)")) || 0
    stats[:average_posts_per_set] = PostSet.average(Arel.sql("cardinality(post_ids)")) || 0

    stats[:safe_posts] = Post.tag_match("rating:s", always_show_deleted: true).count_only
    stats[:questionable_posts] = Post.tag_match("rating:q", always_show_deleted: true).count_only
    stats[:explicit_posts] = Post.tag_match("rating:e", always_show_deleted: true).count_only
    stats[:jpg_posts] = Post.tag_match("type:jpg", always_show_deleted: true).count_only
    stats[:png_posts] = Post.tag_match("type:png", always_show_deleted: true).count_only
    stats[:gif_posts] = Post.tag_match("type:gif", always_show_deleted: true).count_only
    stats[:swf_posts] = Post.tag_match("type:swf", always_show_deleted: true).count_only
    stats[:webm_posts] = Post.tag_match("type:webm", always_show_deleted: true).count_only
    stats[:average_file_size] = Post.average("file_size")
    stats[:total_file_size] = Post.sum("file_size")
    stats[:average_posts_per_day] = daily_average.call(stats[:total_posts])

    ### Users ###

    stats[:total_users] = User.count
    Danbooru.config.levels.each do |name, level|
      stats[:"#{name.downcase}_users"] = User.where(level: level).count
    end
    stats[:unactivated_users] = User.where.not(email_verification_key: nil).count
    stats[:total_dmails] = (Dmail.maximum("id") || 0) / 2
    stats[:average_registrations_per_day] = daily_average.call(stats[:total_users])

    ### Comments ###

    stats[:total_comments] = Comment.maximum("id") || 0
    stats[:active_comments] = Comment.where(is_hidden: false).count
    stats[:hidden_comments] = Comment.where(is_hidden: true).count
    stats[:deleted_comments] = stats[:total_comments] - (stats[:active_comments] + stats[:hidden_comments])
    stats[:average_comments_per_day] = daily_average.call(stats[:total_comments])

    ### Forum posts ###

    stats[:total_forum_threads] = ForumTopic.count
    stats[:total_forum_posts] = ForumPost.maximum("id") || 0
    stats[:average_posts_per_thread] = 0
    stats[:average_posts_per_thread] = (stats[:total_forum_posts] / stats[:total_forum_threads]).round if stats[:total_forum_threads] > 0
    stats[:average_forum_posts_per_day] = daily_average.call(stats[:total_forum_posts])

    ### Blips ###

    stats[:total_blips] = Blip.maximum("id") || 0
    stats[:active_blips] = Blip.where(is_hidden: false).count
    stats[:hidden_blips] = Blip.where(is_hidden: true).count
    stats[:deleted_blips] = stats[:total_blips] - (stats[:active_blips] + stats[:hidden_blips])
    stats[:average_blips_per_day] = daily_average.call(stats[:total_blips])

    ### Tags ###

    stats[:total_tags] = Tag.count
    TagCategory::CATEGORIES.each do |cat|
      stats[:"#{cat}_tags"] = Tag.where(category: TagCategory::MAPPING[cat]).count
    end

    Cache.redis.set("e6stats", stats.to_json)
  end
end
