# frozen_string_literal: true

module Populate
  # Imports the pools that imported posts belong to, trimmed to the posts present locally.
  # A pool comes along once `min_overlap` of its posts are here (or all of them, for smaller pools).
  class PostPools < Importer
    def call
      min_overlap = options.fetch(:min_overlap, 3).to_i
      return { pools: 0, posts: [] } if min_overlap <= 0
      unless available?("pools")
        log "* Skipping pools: no pools export in #{exports_dir}"
        return { pools: 0, posts: [] }
      end

      ensure_loaded!("posts", "pools")
      log "* Importing pools"
      imported = ImportedPosts.sql
      # Pools touching the given posts; without a list, every pool touching any imported post.
      touching = ImportedPosts.sql(options[:post_ids])

      pool_ids = Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          WITH local AS (#{imported}),
          candidates AS (
            SELECT sp.*, sp.post_ids::int[] AS all_ids FROM #{SEED}.pools sp
            WHERE sp.post_ids::int[] && ARRAY(#{touching})::int[]
          ),
          trimmed AS (
            SELECT c.*, ARRAY(
              SELECT u.x FROM unnest(c.all_ids) WITH ORDINALITY AS u(x, ord)
              WHERE u.x IN (SELECT id FROM local) ORDER BY u.ord
            ) AS kept
            FROM candidates c
          )
          INSERT INTO pools (id, name, created_at, updated_at, creator_id, description, is_active, post_ids, category)
          SELECT id, name, created_at, updated_at, creator_id, COALESCE(description, ''), COALESCE(is_active, true), kept, COALESCE(category, 'series')
          FROM trimmed
          WHERE cardinality(kept) >= LEAST(#{min_overlap}, cardinality(all_ids))
          ON CONFLICT (id) DO UPDATE SET post_ids = EXCLUDED.post_ids, updated_at = EXCLUDED.updated_at
          WHERE pools.name = EXCLUDED.name AND pools.post_ids IS DISTINCT FROM EXCLUDED.post_ids
          RETURNING id
        SQL
      end
      log "  pools: #{pool_ids.size} imported or extended"
      return { pools: 0, posts: [] } if pool_ids.empty?

      stub_users_for("SELECT creator_id FROM pools WHERE id = ANY(#{Selection.array_literal(pool_ids)})")
      members = update_post_pool_ids(pool_ids)
      bump_sequences!("pools")
      { pools: pool_ids.size, posts: members }
    end

    private

    # posts.pool_ids mirrors pools.post_ids (as db/fixes/141 backfills it).
    def update_post_pool_ids(pool_ids)
      Exports.with_timeout_off do
        connection.select_values(<<~SQL.squish).map(&:to_i)
          UPDATE posts SET pool_ids = (
            SELECT COALESCE(array_agg(pools.id ORDER BY pools.id), '{}') FROM pools WHERE pools.post_ids @> ARRAY[posts.id]
          )
          WHERE posts.id IN (SELECT unnest(post_ids) FROM pools WHERE id = ANY(#{Selection.array_literal(pool_ids)}))
          RETURNING posts.id
        SQL
      end
    end
  end
end
