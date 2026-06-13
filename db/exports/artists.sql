SELECT
  artists.id,
  artists.name,
  artists.other_names,
  artists.group_name,
  artists.linked_user_id,
  artists.is_active,
  artists.is_locked,
  artists.creator_id,
  artists.created_at,
  artists.updated_at,
  COALESCE(string_agg(artist_urls.url, ' ' ORDER BY artist_urls.id) FILTER (WHERE artist_urls.is_active = TRUE), '')  AS active_urls,
  COALESCE(string_agg(artist_urls.url, ' ' ORDER BY artist_urls.id) FILTER (WHERE artist_urls.is_active = FALSE), '')  AS inactive_urls
FROM artists
       LEFT OUTER JOIN artist_urls ON artist_urls.artist_id = artists.id
GROUP BY artists.id
ORDER BY artists.id
