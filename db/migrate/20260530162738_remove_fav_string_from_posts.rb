# frozen_string_literal: true

class RemoveFavStringFromPosts < ActiveRecord::Migration[8.1]
  def change
    remove_column :posts, :fav_string, :text, default: "", null: false
  end
end
