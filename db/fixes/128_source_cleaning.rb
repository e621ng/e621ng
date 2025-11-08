#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.without_timeout do
  fixed = 0
  Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
    group.each do |post|
      post.strip_source
      if post.changed?
        post.save(validate: false)
        fixed += 1
      end
    end

    puts "batch #{index} fixed #{fixed}"
  end
end
