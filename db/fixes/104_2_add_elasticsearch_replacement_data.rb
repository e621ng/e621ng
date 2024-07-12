#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

Post.find_each do |post|
  puts post.id
  post.document_store.client.update_document_attributes has_pending_replacements: post.replacements.pending.any?
end
