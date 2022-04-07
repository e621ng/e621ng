#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

Ticket.without_timeout do
  Ticket.where(qtype: "namechange").delete_all
end
