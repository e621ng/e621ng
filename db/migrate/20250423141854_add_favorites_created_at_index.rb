# frozen_string_literal: true

class AddFavoritesCreatedAtIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :favorites, :created_at
  end
end
