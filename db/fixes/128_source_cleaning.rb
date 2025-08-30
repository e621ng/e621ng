#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.without_timeout do
  Post.in_batches(load: true, order: :desc).each do |group|
    group.each do |post|
      post.strip_source
      if post.changed?
        post.save(validate: false)
      end
    end
  end
end
