SELECT
  wiki_pages.id,
  wiki_pages.created_at,
  wiki_pages.updated_at,
  wiki_pages.title,
  wiki_pages.body,
  wiki_pages.creator_id,
  wiki_pages.updater_id,
  wiki_pages.is_locked,
  wiki_pages.parent
FROM wiki_pages
ORDER BY wiki_pages.id
