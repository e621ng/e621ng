-- Pending and rejected replacements are filtered out because they are not visible to regular users.
SELECT
  post_replacements2.id,
  post_replacements2.post_id,
  post_replacements2.creator_id,
  post_replacements2.approver_id,
  post_replacements2.file_ext,
  post_replacements2.file_size,
  post_replacements2.image_height,
  post_replacements2.image_width,
  post_replacements2.md5,
  post_replacements2.source,
  post_replacements2.file_name,
  post_replacements2.status,
  post_replacements2.reason,
  post_replacements2.created_at,
  post_replacements2.updated_at
FROM post_replacements2
WHERE post_replacements2.status IN ('approved', 'original')
ORDER BY post_replacements2.id
