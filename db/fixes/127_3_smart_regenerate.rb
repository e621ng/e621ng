#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

puts "Regenerating post thumbnails"
Post.without_timeout do
  sm = Danbooru.config.storage_manager
  queue = Sidekiq::Queue.new("thumb")
  scheduled = 0

  Post.in_batches(load: true, order: :desc).each_with_index do |group, index|
    puts "loaded batch #{index}"

    # Wait for the queue to drain
    sleep 2 while queue.size > 10_000

    skipped = 0
    group.each do |post|
      if post.is_flash?
        skipped += 1
        next
      end

      if File.exist?(sm.file_path(post.md5, post.file_ext, :preview_webp, protect: post.is_deleted?)) &&
         (!post.has_sample? || File.exist?(sm.file_path(post.md5, post.file_ext, :sample_webp, protect: post.is_deleted?)))
        skipped += 1
        next
      end

      scheduled += 1
      PostImageSamplerJob.perform_later(post.id)
      sm.delete_crop_file(post.md5)
    end

    puts "queued #{group.size - skipped} jobs in batch #{index} (skipped #{skipped})"
  end

  puts "finished: queued #{scheduled} jobs total"
end
