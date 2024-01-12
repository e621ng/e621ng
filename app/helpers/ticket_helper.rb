module TicketHelper
  def pretty_ticket_status(ticket)
    status = ticket.status
    if status == "partial"
      "Under Investigation"
    elsif status == "approved"
      "Investigated"
    else
      status.titleize
    end
  end

  def generate_content_warnings(message)
    warnings = []
    if message.creator.is_banned? && message.creator.recent_ban.expires_at.nil?
      warnings << "The creator of this message is already permanently banned."
    end
    warnings << "The creator of this message already received a #{message.warning_type} for its contents." if message.warning_type
    warnings << "The reported message is older than 6 months." if message.updated_at < 6.months.ago

    warnings
  end
end
