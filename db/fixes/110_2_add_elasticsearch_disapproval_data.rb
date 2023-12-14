#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.find_each do |post|
  puts post.id
  post.document_store.client.update(index: Post.document_store.index_name, id: post.id, body: { doc: { disapprover: post.disapprovals.pluck(:user_id) || nil } })
  post.document_store.client.update(index: Post.document_store.index_name, id: post.id, body: { doc: { dis_count: post.disapprovals.count } })
end
