# frozen_string_literal: true

class CreateFavoriteFolderMemberships < ActiveRecord::Migration[8.1]
  def change
    # A sidecar table, deliberately: folder membership is opt-in organizational metadata
    # for a small subset of a user's favorites, not a property of every favorite. Keeping
    # it in its own table means filing something into a folder adds no column, index, or
    # backfill to favorites, and every read of favorites (the flat listing, /favorites.json,
    # non-owner browsing) stays exactly as cheap as it always was, regardless of how
    # heavily folders end up being used. The one exception, spelled out below at the
    # favorite_id FK, is DELETEs from favorites: those do pick up a small, measured,
    # per-row cost from this table's ON DELETE CASCADE constraint trigger.
    create_table :favorite_folder_memberships do |t|
      t.integer  :user_id, null: false
      t.bigint   :folder_id, null: false
      t.bigint   :favorite_id, null: false
      t.integer  :post_id, null: false
      # Denormalized copy of favorites.created_at, captured at filing time. Lets folder
      # pages sort/paginate by "when the post was originally favorited" using only this
      # small table - never touching favorites just to order or count a folder's contents.
      t.datetime :favorite_created_at, null: false
      t.timestamps
    end

    add_foreign_key :favorite_folder_memberships, :users, column: :user_id
    add_foreign_key :favorite_folder_memberships, :favorite_folders, column: :folder_id
    # ON DELETE CASCADE, deliberately kept over an app-level cleanup alternative:
    #
    # Reliability: unfavoriting a post happens from at least 5 call sites (FavoriteManager
    # .remove!, Post#remove_from_favorites, FlushFavoritesJob, and two in
    # TransferFavoritesJob). 4 of those 5 use Favorite.where(...).delete_all, which - unlike
    # destroy/destroy_all - bypasses ActiveRecord callbacks entirely. An after_destroy
    # callback on Favorite would silently miss all 4 of them, so "reliable cleanup without
    # the FK" would mean manually adding a matching FavoriteFolderMembership delete at every
    # current AND future Favorite-deletion call site - exactly the class of easy-to-forget
    # bug a FK exists to prevent (this migration's own first draft already missed
    # TransferFavoritesJob's two sites, which is the point).
    #
    # Cost: this FK does add real, measured overhead to DELETEs from favorites (never to
    # reads/writes-that-aren't-deletes) - it is NOT free, and claiming favorites is fully
    # "untouched" would be inaccurate. Benchmarked (Phase 4.5, e621_benchmark, 5,000,000
    # favorites / 138,400 memberships) via an A/B EXPLAIN (ANALYZE, BUFFERS) comparison that
    # deleted the identical, pre-selected 10,000 favorite ids (all carrying a membership row)
    # first with this FK present, then with it dropped and immediately restored: 165.2ms with
    # the FK vs 19.5ms without, of which the constraint trigger itself accounted for 147.1ms
    # (~89% of the FK-present total) - roughly ~14.6us/row of pure FK overhead, confirming the
    # feature's original benchmark estimate. That overhead scales only with the number of rows
    # actually deleted from favorites and with favorite_folder_memberships' own (small) index
    # size - never with favorites' total row count, since the cascade locates child rows via
    # this table's own favorite_id index, not a scan of favorites. It lands on already-
    # background/batch paths (FlushFavoritesJob, TransferFavoritesJob), not on any user-facing
    # read. (Separately, Phase 4.5 also measured that - with the FK present in both cases -
    # deleting a favorite that actually has a membership costs only ~1.3us/row more than
    # deleting one that doesn't: that narrower number is about membership presence/absence,
    # not about the FK's own overhead, and should not be conflated with the ~14.6us/row figure
    # above.)
    #
    # Net: given 4/5 deletion sites bypass callbacks, the reliability case for the FK
    # outweighs its bounded, non-scaling, delete-path-only cost.
    add_foreign_key :favorite_folder_memberships, :favorites, column: :favorite_id, on_delete: :cascade

    # One Favorite can be filed into at most one folder. Also serves as the lookup index
    # for point moves/removals by favorite_id (move!, unfiling back to root).
    add_index :favorite_folder_memberships, :favorite_id,
              unique: true,
              name: "index_favorite_folder_memberships_on_favorite_id"

    # folder_id-only operations: FavoriteFolderManager's delete_locked! promotion
    # (`.where(folder_id: folder.id).delete_all` / `.update_all(folder_id: new_parent_id)`,
    # run when a folder is deleted and its contents are promoted to the parent/root - NOT
    # issued by move!, which only ever touches a single row by favorite_id) and the
    # dependent: :restrict_with_exception child-existence check on FavoriteFolder all
    # filter on folder_id alone, with no user_id in the predicate. Benchmarked (Phase 4.5):
    # without this index these did a full Seq Scan of the whole membership table
    # regardless of target-folder size; with it, an Index Scan keyed on folder_id.
    add_index :favorite_folder_memberships, :folder_id,
              name: "index_favorite_folder_memberships_on_folder_id"

    # Folder-page listing/count. Serves WHERE user_id = ? AND folder_id = ? plus the
    # canonical ORDER BY favorite_created_at DESC, favorite_id DESC (favorite_id is the
    # tiebreaker for rows sharing the same favorite_created_at) without a separate sort
    # step; folder counts are served by the same index via its leading (user_id, folder_id)
    # prefix. Folder pagination is numbered-only (see PostSets::Favorites) and never orders
    # by this table's own id, so no separate (user_id, folder_id, id) index is needed.
    # Name shortened to stay under Postgres's 63-byte identifier limit - the auto-derived
    # name (with "_on_") is 65 bytes and would be silently truncated.
    add_index :favorite_folder_memberships, %i[user_id folder_id favorite_created_at favorite_id],
              name: "index_favorite_folder_memberships_user_folder_created_favorite"

    # Every membership row's folder_id determines its user_id (a folder belongs to exactly
    # one user), but Postgres's default single-column statistics assume user_id and
    # folder_id are independent - given a query filtering on both (the canonical folder
    # listing/count shape above), it multiplies their individual selectivities together and
    # badly underestimates how many rows actually match. Phase 5.5 measured this directly:
    # Large Folder's real 23,947 rows estimated at ~45 without this object, ~21,972 with
    # it; Medium A's real 7,981 estimated at ~10 vs ~6,658. No execution-time or plan-shape
    # regression was observed either way - this is planner-estimate hardening (guards
    # against a bad plan choice in a more complex future query touching this table), not a
    # claim that it measurably speeds up today's simple queries.
    #
    # Raw SQL wrapped in `reversible`, not a Rails DSL helper - ActiveRecord has none for
    # CREATE STATISTICS. `execute` alone would not be auto-reversible inside `change`;
    # `reversible`'s `dir.down` makes rollback explicit. Ordering is safe by construction:
    # Rails undoes a `change` migration in reverse statement order, so this block's
    # `dir.down` (DROP STATISTICS) always runs before the `create_table` above is reversed
    # (DROP TABLE) - never after.
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          CREATE STATISTICS statistics_ffm_user_folder (dependencies, ndistinct)
            ON user_id, folder_id
            FROM favorite_folder_memberships;
        SQL
      end
      dir.down do
        execute "DROP STATISTICS IF EXISTS statistics_ffm_user_folder;"
      end
    end
  end
end
