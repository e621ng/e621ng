# frozen_string_literal: true

class ReplaceFavoritesUserIdIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    Favorite.without_timeout do
      add_index :favorites, %i[user_id id], name: "index_favorites_on_user_id_and_id", algorithm: :concurrently
      remove_index :favorites, name: "index_favorites_on_user_id_and_created_at", algorithm: :concurrently
    end
  end

  def down
    Favorite.without_timeout do
      add_index :favorites, %i[user_id created_at], name: "index_favorites_on_user_id_and_created_at", algorithm: :concurrently
      remove_index :favorites, name: "index_favorites_on_user_id_and_id", algorithm: :concurrently
    end
  end
end
