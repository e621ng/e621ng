#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

ForumPost.in_batches(of: 100) do |batch|
  updates = []

  # TODO: ensure this still works.
  batch.each do |fp|
    next unless fp.votable? # Skip if the post is not votable
    new_score = fp.send(:vote_score_calculation) # Use the calculation method, NOT update_vote_score
    next if fp.vote_score == new_score # Skip if no change

    # Store [id, score] pairs
    updates << [fp.id, new_score]
  end

  # Bulk update only if there are changes
  unless updates.empty?
    # 1. Extract all scores (the values for the SET clause)
    score_values = updates.map { |_, score| score }.join(", ")

    # 2. Extract all IDs (the values for the WHERE IN clause)
    id_list = updates.map(&:first).join(", ")

    # Construct the SQL: Set vote_score to a list of numbers, where id is in a list of IDs.
    sql = "UPDATE forum_posts SET vote_score = #{score_values} WHERE id IN (#{id_list})"

    ForumPost.connection.execute(sql)
  end
end
