#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

UserStatus.find_each do |user_status|
  user_status.update(ticket_count: Ticket.where(creator_id: user_status.user_id).count)
end
