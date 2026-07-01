SELECT
  tags.id,
  tags.name,
  tags.category,
  tags.post_count,
  tags.created_at,
  tags.updated_at,
  tags.is_locked
FROM tags
ORDER BY tags.id
