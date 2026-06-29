# frozen_string_literal: true

module DiscordReport
  class ModeratorStats < Base
    def webhook_url
      Danbooru.config.moderator_stats_discord_webhook_url
    end

    def report(update_cache: true)
      current_stats = stats
      previous_pending_tickets = Cache.redis.get("ticket_stats:previous_pending_tickets") || current_stats[:pending]
      Cache.redis.set("ticket_stats:previous_pending_tickets", current_stats[:pending]) if update_cache

      diff = current_stats[:pending] - previous_pending_tickets.to_i

      report = []
      report << "```ansi"

      report << "┌─ #{color_bold('MODERATOR REPORT')} ──── #{Time.now.strftime('%Y-%m-%d')} ─┐"
      report << "│ #{color_blue('PENDING QUEUE')}       Change     Rot │"
      report << "│ Tickets  #{format_count(current_stats[:pending])}   #{format_delta(diff)} #{format_count(current_stats[:oldest])}d │"
      report << "├────────────────────────────────────┤"
      report << "│ #{color_blue('DAILY TOTALS')}                       │"
      report << "│ Created #{format_count(current_stats[:created])}                     │"
      report << "│ Handled #{format_count(current_stats[:handled])}                     │"
      report << "└────────────────────────────────────┘"

      report << "```"
      report.join("\n")
    end

    def stats
      oldest = Ticket.active.order(id: :asc).first&.created_at || Time.now
      {
        pending: Ticket.active.count,
        created: Ticket.where("created_at >= ? ", 1.day.ago).count,
        handled: Ticket.approved.where("updated_at >= ? ", 1.day.ago).count,
        oldest: (Time.now - oldest).seconds.in_days.to_i,
      }
    end
  end
end
