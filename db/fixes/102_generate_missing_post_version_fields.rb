#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

Post.find_each do |post|
  puts "#{post.id}"
  prev = PostVersion.new
  post.versions.each do |v|
    v.fill_changes(prev)
    v.update_columns(
        added_tags: v.added_tags,
        removed_tags: v.removed_tags,
        added_locked_tags: v.added_locked_tags,
        removed_locked_tags: v.removed_locked_tags,
        rating_changed: v.rating_changed,
        parent_changed: v.parent_changed,
        source_changed: v.source_changed,
        description_changed: v.description_changed
    )
    prev = v
  end
end
