# frozen_string_literal: true

class CreateSearchTrends < ActiveRecord::Migration[7.1]
  def change
    create_table :search_trends do |t|
      t.string :tag, null: false
      t.date :day, null: false
      t.integer :count, null: false, default: 0

      t.timestamps
    end

    add_index :search_trends, %i[day count]
    add_index :search_trends, %i[tag day], unique: true, name: "index_search_trends_on_tag_and_day"
  end
end
