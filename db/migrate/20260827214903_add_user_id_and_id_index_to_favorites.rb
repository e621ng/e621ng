# frozen_string_literal: true

class AddUserIdAndIdIndexToFavorites < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_favorites_on_user_id_and_id"

  def up
    # Serves sequential (a/b cursor) pagination of a user's favorites, which
    # orders by id. Without it, the planner walks favorites_pkey and filters by
    # user, which times out for users whose favorites are mostly old.
    Favorite.without_timeout do
      add_index :favorites,
                %i[user_id id],
                name: INDEX_NAME,
                algorithm: :concurrently
    end
  end

  def down
    remove_index :favorites, name: INDEX_NAME, algorithm: :concurrently
  end
end
