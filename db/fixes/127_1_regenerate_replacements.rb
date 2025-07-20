#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

puts "Regenerating replacement thumbnails"
PostReplacement.without_timeout do
  PostReplacement.in_batches(load: true, order: :desc).each_with_index do |group, index|
    puts "batch #{index}"
    group.each do |post_replacement|
      ImageSampler.generate_replacement_images(post_replacement)
    end
  end
end
