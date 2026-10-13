# frozen_string_literal: true

class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.text :query, null: false
      t.text :name
      t.boolean :is_tracked, null: false, default: false
      t.bigint :last_seen_post_id
      t.timestamps

      t.index %i[user_id query], unique: true
      t.index %i[user_id name], unique: true, where: "name IS NOT NULL"
    end
  end
end
