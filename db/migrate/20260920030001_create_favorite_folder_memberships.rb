# frozen_string_literal: true

class CreateFavoriteFolderMemberships < ActiveRecord::Migration[8.1]
  def change
    # A sidecar table, deliberately: folder membership is opt-in organizational metadata
    # for a small subset of a user's favorites, not a property of every favorite. Keeping
    # it separate means filing something into a folder adds no column/index/backfill to
    # favorites, and every ordinary read of favorites stays exactly as cheap as before -
    # the one exception (see the favorite_id FK below) is DELETEs from favorites, which
    # pick up a small per-row cost from this table's ON DELETE CASCADE trigger.
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
    # ON DELETE CASCADE, deliberately kept over an app-level cleanup alternative: at least
    # 4 of the 5 call sites that unfavorite a post use Favorite.where(...).delete_all,
    # which bypasses ActiveRecord callbacks entirely, so an after_destroy hook would
    # silently miss most of them. This does add real (small, delete-path-only, non-scaling
    # with favorites' total size) overhead to DELETEs from favorites, landing on
    # already-background/batch paths (FlushFavoritesJob, TransferFavoritesJob), never on a
    # user-facing read - the reliability case outweighs that bounded cost.
    add_foreign_key :favorite_folder_memberships, :favorites, column: :favorite_id, on_delete: :cascade

    # One Favorite can be filed into at most one folder. Also serves as the lookup index
    # for point moves/removals by favorite_id (move!, unfiling back to root).
    add_index :favorite_folder_memberships, :favorite_id,
              unique: true,
              name: "index_favorite_folder_memberships_on_favorite_id"

    # folder_id-only operations: FavoriteFolderManager's delete_locked! promotion (run when
    # a folder is deleted and its contents promoted to the parent/root) and the
    # dependent: :restrict_with_exception child-existence check on FavoriteFolder both
    # filter on folder_id alone, with no user_id in the predicate.
    add_index :favorite_folder_memberships, :folder_id,
              name: "index_favorite_folder_memberships_on_folder_id"

    # Folder-page listing/count: serves WHERE user_id = ? AND folder_id = ? plus the
    # canonical ORDER BY favorite_created_at DESC, favorite_id DESC (tiebreaker) without a
    # separate sort step; counts reuse the same index via its (user_id, folder_id) prefix.
    # Name shortened to stay under Postgres's 63-byte identifier limit - the auto-derived
    # name is 65 bytes and would be silently truncated.
    add_index :favorite_folder_memberships, %i[user_id folder_id favorite_created_at favorite_id],
              name: "index_favorite_folder_memberships_user_folder_created_favorite"

    # Every row's folder_id determines its user_id (a folder belongs to exactly one user),
    # but Postgres's default single-column statistics assume the two are independent and
    # multiply their selectivities together, badly underestimating a query that filters on
    # both (the canonical folder listing/count shape above). This is planner-estimate
    # hardening against a bad plan choice, not a claim it speeds up today's simple queries.
    #
    # Raw SQL wrapped in `reversible` since ActiveRecord has no DSL helper for CREATE
    # STATISTICS; `dir.down` makes rollback explicit. Rails undoes a `change` migration in
    # reverse statement order, so this always reverses before the `create_table` above does.
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
