#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.where("(file_ext = ? OR file_ext = ?) AND generated_samples IS NOT NULL", "webm", "mp4").find_each do |post|
  # next if post.video_samples.empty?
  PostVideoConversionJob.perform_later(post.id)
end
