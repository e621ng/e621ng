# frozen_string_literal: true

class ReplaceFavoritesIndex < ActiveRecord::Migration[7.1]
  def change
    Favorite.without_timeout do
      remove_index :favorites, :created_at

      add_index :favorites, %i[user_id created_at]
    end
  end
end
