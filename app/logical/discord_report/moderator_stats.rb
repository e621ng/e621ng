module DiscordReport
  class ModeratorStats < Base
    def webhook_url
      Danbooru.config.moderator_stats_discord_webhook_url
    end

    def run!
      return if webhook_url.blank?

      current_stats = stats
      previous_pending_tickets = Cache.redis.get("ticket_stats:previous_pending_tickets") || current_stats[:pending]
      Cache.redis.set("ticket_stats:previous_pending_tickets", current_stats[:pending])

      diff = current_stats[:pending] - previous_pending_tickets.to_i
      content = <<~REPORT.chomp
        Moderator report for <t:#{Time.now.to_i}:D>
        Currently, there are:
        #{formatted_number(current_stats[:pending])} pending tickets. That is #{formatted_number(diff.abs)} #{diff >= 0 ? 'more' : 'fewer'} than the day before.
        #{formatted_number(current_stats[:created])} tickets were created yesterday.
        #{formatted_number(current_stats[:handled])} tickets were handled yesterday.
        The oldest pending ticket was created #{formatted_number(current_stats[:oldest])} days ago.
      REPORT

      post_webhook(content)
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
