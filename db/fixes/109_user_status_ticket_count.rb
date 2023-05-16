#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

User.find_each do |user|
  UserStatus.for_user(user.id).update_all(ticket_count: Ticket.where(creator_id: user.id).count)
end
