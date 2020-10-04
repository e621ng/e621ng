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
end
