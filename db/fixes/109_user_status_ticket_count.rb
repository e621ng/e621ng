#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

UserStatus.find_each do |user_status|
  user_status.update_column(:ticket_count, Ticket.for_user(user_status.user_id).count)
end
