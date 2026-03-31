# frozen_string_literal: true

class CreateSearchTrends < ActiveRecord::Migration[7.2]
  def change
    # SearchTrends
    SearchTrend.without_timeout do
      create_table :search_trends do |t|
        t.string :tag, null: false
        t.date :day, null: false
        t.integer :count, null: false, default: 0

        t.timestamps
      end

      add_index :search_trends, %i[day count]
      add_index :search_trends, %i[tag day], unique: true, name: "index_search_trends_on_tag_and_day"
    end

    # SearchTrendBlacklists
    SearchTrendBlacklist.without_timeout do
      create_table :search_trend_blacklists do |t|
        t.string :tag, null: false
        t.string :reason, null: false, default: ""
        t.references :creator, foreign_key: { to_table: :users }, null: false

        t.timestamps
      end

      add_index :search_trend_blacklists, :tag, unique: true
    end
  end
end
