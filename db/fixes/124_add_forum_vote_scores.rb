#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

ForumPost.in_batches(of: 100) do |batch|
  updates = []

  batch.each do |fp|
    next unless fp.votable? # Skip if the post is not votable
    new_score = fp.send(:vote_score) # Use the calculation method, NOT update_vote_score
    next if fp.vote_score == new_score # Skip if no change

    updates << [fp.id, new_score]
  end

  # Bulk update only if there are changes
  unless updates.empty?
    sql = "UPDATE forum_posts SET vote_score = %s WHERE id IN (%s)"
    values = updates.map { |id, score| "(#{score}, #{id})" }.join(", ")
    sql %= [values, updates.map(&:first).join(", ")]
    ForumPost.connection.execute(sql)
  end
end
