SELECT
  pools.id,
  pools.name,
  pools.created_at,
  pools.updated_at,
  pools.creator_id,
  pools.description,
  pools.is_active,
  pools.category,
  pools.post_ids
FROM pools
ORDER BY pools.id
