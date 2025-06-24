#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.without_timeout do
  Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
    puts "batch #{index}"
    group.each do |post|
      PostImageSamplerJob.perform_later(post.id)
    end
  end
end
