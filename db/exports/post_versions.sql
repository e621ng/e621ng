-- Hidden versions are filtered out because they contain changes that are not visible to regular users.
SELECT
  post_versions.id,
  post_versions.post_id,
  post_versions.version,
  post_versions.tags,
  post_versions.added_tags,
  post_versions.removed_tags,
  post_versions.locked_tags,
  post_versions.added_locked_tags,
  post_versions.removed_locked_tags,
  post_versions.rating,
  post_versions.rating_changed,
  post_versions.parent_id,
  post_versions.parent_changed,
  post_versions.source,
  post_versions.source_changed,
  post_versions.description,
  post_versions.description_changed,
  post_versions.updater_id,
  post_versions.updated_at,
  post_versions.reason
FROM post_versions
WHERE post_versions.is_hidden = false
ORDER BY post_versions.id
