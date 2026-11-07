#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# Mirrors ForumPost#vote_score_calculation: (up - down) / total.
# Only posts with votes get a score, same as the after_commit on ForumPostVote.
ForumPost.connection.execute(<<~SQL.squish)
  UPDATE forum_posts
  SET vote_score = scores.score
  FROM (
    SELECT forum_post_id,
           SUM(CASE score WHEN 1 THEN 1 WHEN -1 THEN -1 ELSE 0 END)::numeric / COUNT(*) AS score
    FROM forum_post_votes
    GROUP BY forum_post_id
  ) scores
  WHERE forum_posts.id = scores.forum_post_id
    AND forum_posts.vote_score IS DISTINCT FROM scores.score
SQL
