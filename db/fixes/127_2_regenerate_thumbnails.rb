#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

puts "Regenerating post thumbnails"
Post.without_timeout do
  sm = Danbooru.config.storage_manager
  Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
    puts "batch #{index}"
    group.each do |post|
      PostImageSamplerJob.perform_later(post.id)
      sm.delete_crop_file(post.md5)
    end
  end
end
