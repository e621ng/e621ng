#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

ForumPost.in_batches(of: 100) do |batch|
  updates = []

  batch.each do |fp|
    next unless fp.votable? # Skip if the post is not votable
    new_score = fp.send(:vote_score_calculation) # Use the calculation method, NOT update_vote_score
    next if fp.vote_score == new_score # Skip if no change

    # Store [id, score] pairs
    updates << [fp.id, new_score]
  end

  # Bulk update only if there are changes
  unless updates.empty?
    # Extract all IDs (the values for the WHERE IN clause)
    # Build the CASE WHEN structure: "WHEN id = 1 THEN 0.5 WHEN id = 2 THEN -0.5 ..."
    case_statements = updates.map do |id, score|
      "WHEN id = #{id} THEN #{score}"
    end.join(" ")

    # Construct the final SQL using CASE: Set vote_score to a list of numbers, where id is in a list of IDs.
    # UPDATE table SET column = CASE WHEN ... END WHERE condition;
    sql = "UPDATE forum_posts SET vote_score = CASE #{case_statements} END WHERE id IN (#{updates.map(&:first).join(', ')})"
    ForumPost.connection.execute(sql)
  end
end
