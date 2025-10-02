#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# We intend to re-use several boolean attributes in the future.
# Some posts may already have them set, so it's best to clear them all out.
Post.without_timeout do
  fixed = 0
  Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
    group.each do |post|
      post._has_embedded_notes = false
      post._has_cropped = false

      if post.changed?
        post.save(validate: false)
        fixed += 1
      end
    end

    puts "batch #{index} fixed #{fixed}"
  end
end
