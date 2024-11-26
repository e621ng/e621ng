#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

client = Post.document_store.client
Post.find_in_batches(batch_size: 10_000) do |posts|
  client.bulk(body: posts.map { |post| { update: { _index: Post.document_store.index_name, _id: post.id, data: { doc: { tag_count_contributor: 0 } } } } }, refresh: true)
end
