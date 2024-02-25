#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment'))

Note.where("x < 0").in_batches.update_all(x: 0)
Note.where("y < 0").in_batches.update_all(y: 0)
Note.where("width < 0").in_batches.update_all(width: 0)
Note.where("height < 0").in_batches.update_all(height: 0)

Note.joins(:post).includes(:post).where("x > posts.image_width").find_each do |note|
  note.update_column(:x, note.post.image_width)
end

Note.joins(:post).includes(:post).where("y > posts.image_height").find_each do |note|
  note.update_column(:y, note.post.image_height)
end

Note.joins(:post).includes(:post).where("x + width > posts.image_width").find_each do |note|
  note.update_column(:width, note.post.image_width - note.x)
end

Note.joins(:post).includes(:post).where("y + height > posts.image_height").find_each do |note|
  note.update_column(:height, note.post.image_height - note.y)
end
