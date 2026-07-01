# frozen_string_literal: true

module DiscordReport
  class JanitorStats < Base
    def webhook_url
      Danbooru.config.janitor_reports_discord_webhook_url
    end

    def report(update_cache: true)
      current_stats = stats

      # This could be optimized by using a single Redis hash instead of multiple keys.
      # However, since this runs once per day and the number of keys is small, the performance impact is negligible.
      previous_pending_posts = Cache.redis.get("janitor_reports:previous_pending_posts") || current_stats[:pending][:posts]
      previous_pending_replacements = Cache.redis.get("janitor_reports:previous_pending_replacements") || current_stats[:pending][:replacements]
      previous_pending_flags = Cache.redis.get("janitor_reports:previous_pending_flags") || current_stats[:pending][:flags]
      previous_pending_appeals = Cache.redis.get("janitor_reports:previous_pending_appeals") || current_stats[:pending][:appeals]
      if update_cache
        Cache.redis.set("janitor_reports:previous_pending_posts", current_stats[:pending][:posts])
        Cache.redis.set("janitor_reports:previous_pending_replacements", current_stats[:pending][:replacements])
        Cache.redis.set("janitor_reports:previous_pending_flags", current_stats[:pending][:flags])
        Cache.redis.set("janitor_reports:previous_pending_appeals", current_stats[:pending][:appeals])
      end

      diff_posts = current_stats[:pending][:posts] - previous_pending_posts.to_i
      diff_replacements = current_stats[:pending][:replacements] - previous_pending_replacements.to_i
      diff_flags = current_stats[:pending][:flags] - previous_pending_flags.to_i
      diff_appeals = current_stats[:pending][:appeals] - previous_pending_appeals.to_i

      report = []
      report << "```ansi"

      report << "┌─ #{color_bold('JANITOR REPORT')} ────── #{Time.now.strftime('%Y-%m-%d')} ─┐"
      report << "│ #{color_blue('PENDING QUEUE')}       Change     Rot │"
      report << "│ Posts    #{format_count(current_stats[:pending][:posts])}   #{format_delta(diff_posts)}   #{format_count(current_stats[:oldest][:posts], length: 4)}d │"
      report << "│ Flags    #{format_count(current_stats[:pending][:flags])}   #{format_delta(diff_flags)}   #{format_count(current_stats[:oldest][:flags], length: 4)}d │"
      report << "│ Replac.  #{format_count(current_stats[:pending][:replacements])}   #{format_delta(diff_replacements)}   #{format_count(current_stats[:oldest][:replacements], length: 4)}d │"
      report << "│ Appeals  #{format_count(current_stats[:pending][:appeals])}   #{format_delta(diff_appeals)}   #{format_count(current_stats[:oldest][:appeals], length: 4)}d │"
      report << "├─────────────────┬──────────────────┤"
      report << "│ #{color_blue('DAILY TOTALS')}    │ #{color_blue('DELETIONS')} #{format_count(current_stats[:deletions][:total])} │"
      report << "│ Added    #{format_count(current_stats[:posts])} │ automatic #{format_count(current_stats[:deletions][:automod] - current_stats[:deletions][:takedowns])} │"
      report << "│ Handled  #{format_count(current_stats[:approvals] + current_stats[:deletions][:total])} │ takedown  #{format_count(current_stats[:deletions][:takedowns])} │"
      report << "│ Approved #{format_count(current_stats[:approvals])} │ manual    #{format_count(current_stats[:deletions][:total] - current_stats[:deletions][:automod])} │"
      report << "└─────────────────┴──────────────────┘"

      report << "```"
      report.join("\n")
    end

    def stats
      deletions = PostFlag.where(is_deletion: true).where("created_at >= ?", 1.day.ago)
      oldest_pending_post = Post.pending.order(id: :asc).first&.created_at || Time.now
      # HACK: This method doesn't work because flags are not resolved when a post is deleted.
      # For now, we will get our valid flags based on post status instead - adding a post_id constraint. We have an index of `index_post_flags_on_post_id`, so this should be efficient.
      flagged_posts = Post.where(is_flagged: true) # relation of flagged posts
      oldest_pending_flag = PostFlag.where(is_deletion: false, is_resolved: false, post_id: flagged_posts).order(id: :asc).first&.created_at || Time.now
      oldest_pending_replacement = PostReplacement.pending.order(id: :asc).first&.created_at || Time.now
      oldest_appeal = Appeal.active.order(id: :asc).first&.created_at || Time.now
      {
        pending: {
          posts: Post.pending.count,
          flags: flagged_posts.count, # use the relation count instead of loading ids into memory
          replacements: PostReplacement.pending.count,
          appeals: Appeal.active.count,
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
          appeals: (Time.now - oldest_appeal).seconds.in_days.to_i,
        },
        approvals: PostApproval.where("created_at >= ?", 1.day.ago).count,
        posts: Post.where("created_at >= ? ", 1.day.ago).count,
      }
    end
  end
end
