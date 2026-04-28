# frozen_string_literal: true

module DiscordReport
  class JanitorStats < Base
    def webhook_url
      Danbooru.config.janitor_reports_discord_webhook_url
    end

    def report
      current_stats = stats

      # This could be optimized by using a single Redis hash instead of multiple keys.
      # However, since this runs once per day and the number of keys is small, the performance impact is negligible.
      previous_pending_posts = Cache.redis.get("janitor_reports:previous_pending_posts") || current_stats[:pending][:posts]
      previous_pending_replacements = Cache.redis.get("janitor_reports:previous_pending_replacements") || current_stats[:pending][:replacements]
      previous_pending_flags = Cache.redis.get("janitor_reports:previous_pending_flags") || current_stats[:pending][:flags]

      Cache.redis.set("janitor_reports:previous_pending_posts", current_stats[:pending][:posts])
      Cache.redis.set("janitor_reports:previous_pending_replacements", current_stats[:pending][:replacements])
      Cache.redis.set("janitor_reports:previous_pending_flags", current_stats[:pending][:flags])

      diff_posts = current_stats[:pending][:posts] - previous_pending_posts.to_i
      diff_replacements = current_stats[:pending][:replacements] - previous_pending_replacements.to_i
      diff_flags = current_stats[:pending][:flags] - previous_pending_flags.to_i

      <<~REPORT.chomp
        Janitor report for <t:#{Time.now.to_i}:D>
        Currently, there are:
        #{formatted_number(current_stats[:pending][:posts])} pending posts. That is #{more_fewer(diff_posts)} than the day before. The oldest pending post was created #{formatted_number(current_stats[:oldest][:posts])} days ago.
        #{formatted_number(current_stats[:pending][:flags])} pending flags. That is #{more_fewer(diff_flags)} than the day before. The oldest pending flag was created #{formatted_number(current_stats[:oldest][:flags])} days ago.
        #{formatted_number(current_stats[:pending][:replacements])} pending replacements. That is #{more_fewer(diff_replacements)} than the day before. The oldest pending replacement was created #{formatted_number(current_stats[:oldest][:replacements])} days ago.

        #{formatted_number(current_stats[:posts])} posts were uploaded yesterday.

        #{formatted_number(current_stats[:approvals] + current_stats[:deletions][:total])} posts were processed.
        Approvals: #{formatted_number(current_stats[:approvals])}
        Deletions: #{formatted_number(current_stats[:deletions][:total])} (#{formatted_number(current_stats[:deletions][:automod] - current_stats[:deletions][:takedowns])} automated, #{formatted_number(current_stats[:deletions][:takedowns])} takedown, #{formatted_number(current_stats[:deletions][:total] - current_stats[:deletions][:automod])} manual)
      REPORT
    end

    def stats
      deletions = PostFlag.where(is_deletion: true).where("created_at >= ?", 1.day.ago)
      oldest_pending_post = Post.pending.order(id: :asc).first&.created_at || Time.now
      # HACK: This method doesn't work because flags are not resolved when a post is deleted.
      # For now, we will get our valid flags based on post status instead - adding a post_id constraint. We have an index of `index_post_flags_on_post_id`, so this should be efficient.
      flagged_posts = Post.where(is_flagged: true) # relation of flagged posts
      oldest_pending_flag = PostFlag.where(is_deletion: false, is_resolved: false, post_id: flagged_posts).order(id: :asc).first&.created_at || Time.now
      oldest_pending_replacement = PostReplacement.pending.order(id: :asc).first&.created_at || Time.now
      {
        pending: {
          posts: Post.pending.count,
          flags: flagged_posts.count, # use the relation count instead of loading ids into memory
          replacements: PostReplacement.pending.count,
        },
        deletions: {
          total: deletions.count,
          automod: deletions.where(creator_id: User.system.id).count,
          takedowns: deletions.where("reason LIKE ?", "takedown #%").count,
        },
        oldest: {
          posts: (Time.now - oldest_pending_post).seconds.in_days.to_i,
          flags: (Time.now - oldest_pending_flag).seconds.in_days.to_i,
          replacements: (Time.now - oldest_pending_replacement).seconds.in_days.to_i,
        },
        approvals: PostApproval.where("created_at >= ?", 1.day.ago).count,
        posts: Post.where("created_at >= ? ", 1.day.ago).count,
      }
    end
  end
end
