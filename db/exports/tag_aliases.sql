SELECT
  tag_aliases.id,
  tag_aliases.antecedent_name,
  tag_aliases.consequent_name,
  tag_aliases.created_at,
  tag_aliases.status,
  tag_aliases.forum_post_id,
  tag_aliases.forum_topic_id,
  tag_aliases.reason,
  tag_aliases.updated_at,
  tag_aliases.approver_id,
  tag_aliases.post_count,
  COALESCE(votes.down, 0) AS down_votes,
  COALESCE(votes.meh, 0)  AS meh_votes,
  COALESCE(votes.up, 0)   AS up_votes
FROM tag_aliases
LEFT JOIN (
  SELECT
    forum_post_votes.forum_post_id,
    COUNT(*) FILTER (WHERE forum_post_votes.score = -1) AS down,
    COUNT(*) FILTER (WHERE forum_post_votes.score = 0)  AS meh,
    COUNT(*) FILTER (WHERE forum_post_votes.score = 1)  AS up
  FROM forum_post_votes
  GROUP BY forum_post_votes.forum_post_id
) votes ON votes.forum_post_id = tag_aliases.forum_post_id
ORDER BY tag_aliases.id
