#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.without_timeout do
  Post.order("id DESC").find_in_batches.with_index do |group, index|
    puts "Scheduled batch #{index} with #{group.size} posts"
    group.each do |post|
      PostSamplerJob.perform_later(post.id)
    end
  end
end
