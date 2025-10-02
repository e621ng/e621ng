#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# We intend to re-use several boolean attributes in the future.
# Some posts may already have them set, so it's best to clear them all out.
Post.without_timeout do
  queue = Sidekiq::Queue.new("high_prio")
  fixed = 0

  Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
    puts "batch #{index} fixed #{fixed} (queue size: #{queue.size})"

    # Wait for the queue to drain
    sleep 2 while queue.size > 1_000

    group.each do |post|
      post.is_animated = post.file_path.present? ? post.is_animated_file?(post.file_path) : false

      if post.changed?
        post.save(validate: false)
        fixed += 1
      end
    end
  end
end
