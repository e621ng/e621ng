# frozen_string_literal: true

class ReplacePoolStringWithPoolAndSetIds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_POOL_IDS = "index_posts_on_pool_ids"
  INDEX_SET_IDS = "index_posts_on_set_ids"
  INDEX_POOL_STRING_TOKENS = "index_posts_on_pool_string_tokens"

  def up
    add_column :posts, :pool_ids, :integer, array: true, null: false, default: []
    add_column :posts, :set_ids, :bigint, array: true, null: false, default: []

    Post.without_timeout { backfill_pool_ids }
    Post.without_timeout { backfill_set_ids }

    add_index :posts, :pool_ids, using: :gin, name: INDEX_POOL_IDS, algorithm: :concurrently
    add_index :posts, :set_ids, using: :gin, name: INDEX_SET_IDS, algorithm: :concurrently

    remove_index :posts, name: INDEX_POOL_STRING_TOKENS, algorithm: :concurrently
    remove_column :posts, :pool_string
  end

  def down
    add_column :posts, :pool_string, :text, null: false, default: ""

    Post.without_timeout { restore_pool_string }

    add_index :posts, "string_to_array(pool_string, ' ')", using: :gin, name: INDEX_POOL_STRING_TOKENS, algorithm: :concurrently

    remove_index :posts, name: INDEX_POOL_IDS, algorithm: :concurrently
    remove_index :posts, name: INDEX_SET_IDS, algorithm: :concurrently

    remove_column :posts, :pool_ids
    remove_column :posts, :set_ids
  end

  private

  def backfill_pool_ids
    execute <<~SQL.squish
      UPDATE posts
      SET pool_ids = COALESCE(pool_memberships.pool_ids, '{}')
      FROM (
        SELECT post_id, array_agg(pool_id ORDER BY pool_id) AS pool_ids
        FROM (
          SELECT post_ids.post_id, pools.id AS pool_id
          FROM pools
          CROSS JOIN LATERAL unnest(pools.post_ids) AS post_ids(post_id)

          UNION

          SELECT posts.id AS post_id, substring(tokens.token FROM '^pool:(\\d+)$')::int AS pool_id
          FROM posts
          CROSS JOIN LATERAL unnest(string_to_array(posts.pool_string, ' ')) AS tokens(token)
          WHERE tokens.token ~ '^pool:\\d+$'
        ) combined_pool_memberships
        GROUP BY post_id
      ) pool_memberships
      WHERE posts.id = pool_memberships.post_id
    SQL
  end

  def backfill_set_ids
    execute <<~SQL.squish
      UPDATE posts
      SET set_ids = COALESCE(set_memberships.set_ids, '{}')
      FROM (
        SELECT post_id, array_agg(set_id ORDER BY set_id) AS set_ids
        FROM (
          SELECT post_ids.post_id, post_sets.id AS set_id
          FROM post_sets
          CROSS JOIN LATERAL unnest(post_sets.post_ids) AS post_ids(post_id)

          UNION

          SELECT posts.id AS post_id, substring(tokens.token FROM '^set:(\\d+)$')::bigint AS set_id
          FROM posts
          CROSS JOIN LATERAL unnest(string_to_array(posts.pool_string, ' ')) AS tokens(token)
          WHERE tokens.token ~ '^set:\\d+$'
        ) combined_set_memberships
        GROUP BY post_id
      ) set_memberships
      WHERE posts.id = set_memberships.post_id
    SQL
  end

  def restore_pool_string
    execute <<~SQL.squish
      UPDATE posts
      SET pool_string = COALESCE(pool_tokens.pool_string, '')
      FROM (
        SELECT post_id, array_to_string(array_agg(token ORDER BY token_type, token_id), ' ') AS pool_string
        FROM (
          SELECT posts.id AS post_id, 'pool:' || pool_id AS token, 0 AS token_type, pool_id::bigint AS token_id
          FROM posts
          CROSS JOIN LATERAL unnest(posts.pool_ids) AS pool_ids(pool_id)

          UNION

          SELECT posts.id AS post_id, 'set:' || set_id AS token, 1 AS token_type, set_id AS token_id
          FROM posts
          CROSS JOIN LATERAL unnest(posts.set_ids) AS set_ids(set_id)
        ) tokens
        GROUP BY post_id
      ) pool_tokens
      WHERE posts.id = pool_tokens.post_id
    SQL
  end
end
