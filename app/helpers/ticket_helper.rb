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

  def generate_comment_warnings(comment)
    warnings = []
    if comment.creator.is_banned? && comment.creator.recent_ban.expires_at.nil?
      warnings << "The creator of this comment is already permanently banned"
    end
    warnings << "The creator of this comment already received a #{comment.warning_type} for its contents" if comment.warning_type
    warnings << "The reported comment is older than 6 months" if comment.updated_at < 6.months.ago

    warnings
  end
end
