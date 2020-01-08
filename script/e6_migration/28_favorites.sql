-- dedup with
-- \copy (select user_id, post_id from favorites) to 'favorites.dump'
-- sort -u favorites.dump > uniq_favorites.dump
-- truncate table favorites;
-- alter sequence favorites_id_seq restart;
-- \copy favorites (user_id, post_id) from './uniq_favorites.dump'

delete from favorites a using favorites b where a.id < b.id and a.post_id = b.post_id and a.user_id = b.user_id;