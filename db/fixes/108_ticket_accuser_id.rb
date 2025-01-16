#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Ticket.where(qtype: "blip").find_each do |ticket|
  ticket.update_column(:accused_id, Blip.find_by(id: ticket.disp_id)&.creator_id)
end

Ticket.where(qtype: "forum").find_each do |ticket|
  ticket.update_column(:accused_id, ForumPost.find_by(id: ticket.disp_id)&.creator_id)
end

Ticket.where(qtype: "comment").find_each do |ticket|
  ticket.update_column(:accused_id, Comment.find_by(id: ticket.disp_id)&.creator_id)
end

Ticket.where(qtype: "dmail").find_each do |ticket|
  ticket.update_column(:accused_id, Dmail.find_by(id: ticket.disp_id)&.from_id)
end

Ticket.where(qtype: "user").find_each do |ticket|
  ticket.update_column(:accused_id, ticket.disp_id)
end
