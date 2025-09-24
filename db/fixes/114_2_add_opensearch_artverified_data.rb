#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

artists = Artist.select(:name, :linked_user_id).where.not(linked_user_id: nil).to_h { |artist| [artist.name, artist.linked_user_id] }

client = Post.document_store.client
Post.find_each do |post|
  puts post.id
  client.update(index: Post.document_store.index_name, id: post.id, body: { doc: { artverified: post.tag_array.any? { |tag| artists.key?(tag) && artists[tag] == post.uploader_id } } })
end
