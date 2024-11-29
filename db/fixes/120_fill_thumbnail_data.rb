#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

CurrentUser.as_system do
  Post.where(thumbnail: nil).find_each do |post|
    puts post.id
    side = [post.image_width, post.image_height].min
    post.thumbnail = "0/0/#{side}"
    post.save!
  end
end
