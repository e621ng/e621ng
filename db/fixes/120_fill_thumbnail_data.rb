#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

CurrentUser.as_system do
  counter = 0
  Post.find_each do |post|
    counter += 1
    puts "scheduled: #{counter}" if counter % 1000

    side = [post.image_width, post.image_height].min
    if post.image_width > post.image_height
      origin = ((post.image_width - side) / 2).floor
      post.thumbnail = "#{origin}/0/#{side}"
    else
      post.thumbnail = "0/0/#{side}"
    end
    post.save!

    ThumbnailJob.perform_later(post.id)
  end
  puts "finished: #{counter}"
end
