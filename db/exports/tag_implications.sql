SELECT
  tag_implications.id,
  tag_implications.antecedent_name,
  tag_implications.consequent_name,
  tag_implications.created_at,
  tag_implications.status,
  tag_implications.forum_post_id,
  tag_implications.forum_topic_id,
  tag_implications.reason,
  tag_implications.updated_at,
  tag_implications.approver_id,
  tag_implications.descendant_names,
  COALESCE(votes.down, 0) AS down_votes,
  COALESCE(votes.meh, 0)  AS meh_votes,
  COALESCE(votes.up, 0)   AS up_votes
FROM tag_implications
LEFT JOIN (
  SELECT
    forum_post_votes.forum_post_id,
    COUNT(*) FILTER (WHERE forum_post_votes.score = -1) AS down,
    COUNT(*) FILTER (WHERE forum_post_votes.score = 0)  AS meh,
    COUNT(*) FILTER (WHERE forum_post_votes.score = 1)  AS up
  FROM forum_post_votes
  GROUP BY forum_post_votes.forum_post_id
) votes ON votes.forum_post_id = tag_implications.forum_post_id
ORDER BY tag_implications.id
