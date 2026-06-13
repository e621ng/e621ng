SELECT
  bulk_update_requests.id,
  bulk_update_requests.user_id,
  bulk_update_requests.forum_topic_id,
  bulk_update_requests.forum_post_id,
  bulk_update_requests.script,
  bulk_update_requests.status,
  bulk_update_requests.approver_id,
  bulk_update_requests.title,
  bulk_update_requests.created_at,
  bulk_update_requests.updated_at,
  COALESCE(votes.down, 0) AS down_votes,
  COALESCE(votes.meh, 0)  AS meh_votes,
  COALESCE(votes.up, 0)   AS up_votes
FROM bulk_update_requests
LEFT JOIN LATERAL (
  SELECT
      COUNT(*) FILTER (WHERE forum_post_votes.score = -1) AS down,
      COUNT(*) FILTER (WHERE forum_post_votes.score = 0)  AS meh,
      COUNT(*) FILTER (WHERE forum_post_votes.score = 1)  AS up
  FROM forum_post_votes
  WHERE forum_post_votes.forum_post_id = bulk_update_requests.forum_post_id
) votes ON true
ORDER BY bulk_update_requests.id
