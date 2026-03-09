# frozen_string_literal: true

module DiscordReport
  class JanitorStats < Base
    def webhook_url
      Danbooru.config.janitor_reports_discord_webhook_url
    end

    def report
      current_stats = stats
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
        #{formatted_number(current_stats[:pending][:posts])} pending posts. That is #{more_fewer(diff_posts)} than the day before.
        #{formatted_number(current_stats[:pending][:flags])} pending flags. That is #{more_fewer(diff_flags)} than the day before.
        #{formatted_number(current_stats[:pending][:replacements])} pending replacements. That is #{more_fewer(diff_replacements)} than the day before.

        #{formatted_number(current_stats[:posts])} posts were uploaded yesterday.

        #{formatted_number(current_stats[:approvals] + current_stats[:deletions][:total])} posts were processed.
        Approvals: #{formatted_number(current_stats[:approvals])}
        Deletions: #{formatted_number(current_stats[:deletions][:total])} (#{formatted_number(current_stats[:deletions][:automod] - current_stats[:deletions][:takedowns])} automated, #{formatted_number(current_stats[:deletions][:takedowns])} takedown, #{formatted_number(current_stats[:deletions][:total] - current_stats[:deletions][:automod])} manual)
      REPORT
    end

    def stats
      deletions = PostFlag.where(is_deletion: true).where("created_at >= ?", 1.day.ago)
      {
        pending: {
          posts: Post.pending.count,
          flags: Post.where(is_flagged: true).count,
          replacements: PostReplacement.pending.count,
        },
        deletions: {
          total: deletions.count,
          automod: deletions.where(creator_id: User.system.id).count,
          takedowns: deletions.where("reason LIKE ?", "takedown #%").count,
        },
        approvals: PostApproval.where("created_at >= ?", 1.day.ago).count,
        posts: Post.where("created_at >= ? ", 1.day.ago).count,
      }
    end
  end
end
