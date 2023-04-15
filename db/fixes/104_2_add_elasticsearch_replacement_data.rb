#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

Post.find_each do |post|
  puts post.id
  post.__elasticsearch__.update_document_attributes has_pending_replacements: post.replacements.pending.any?
end
