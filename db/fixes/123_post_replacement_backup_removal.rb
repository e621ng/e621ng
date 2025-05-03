#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

PostReplacement.where(status: "original").find_each do |r| # for all replacements with status 'original'
  match = PostReplacement.where(status: "original", post_id: r.post_id).first.id.equal?(r.id)
  unless match # if they are not the first original for the post
    puts "replacement #{r.id} - duplicate removed"
    r.destroy # remove backups
  end
end
