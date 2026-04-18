# frozen_string_literal: true

class SplitSearchTrendsIntoHourlyAndDaily < ActiveRecord::Migration[8.1]
  def up
    SearchTrend.without_timeout do
      # Create the new search_trend_hourlies table with final schema
      create_table :search_trend_hourlies do |t|
        t.string :tag, null: false
        t.datetime :hour, null: false
        t.integer :count, null: false, default: 0
        t.boolean :processed, null: false, default: false

        t.timestamps
      end

      # Add indexes for the hourly table
      add_index :search_trend_hourlies, %i[tag hour], unique: true
      add_index :search_trend_hourlies, :hour

      # Performance indexes
      add_index :search_trend_hourlies, :processed, name: "index_search_trend_hourlies_on_processed"
      add_index :search_trend_hourlies, %i[processed hour], name: "index_search_trend_hourlies_on_processed_and_hour"
      add_index :search_trend_hourlies, :hour, where: "processed = false", name: "index_search_trend_hourlies_on_hour_unprocessed"

      add_index :search_trends, %i[tag day], unique: true, name: "index_search_trends_on_tag_and_day"
      add_index :search_trends, :tag, using: :gin, opclass: { tag: :gin_trgm_ops }, name: "index_search_trends_on_tag_trigram"

      # Clean up existing hourly records from search_trends (they'll be rebuilt by normal operation)
      execute("DELETE FROM search_trends WHERE hour IS NOT NULL")

      # Remove the partial indexes that differentiated hourly from daily records
      remove_index :search_trends, name: "index_search_trends_on_tag_day_hour" if index_exists?(:search_trends, %i[tag day hour], name: "index_search_trends_on_tag_day_hour")
      remove_index :search_trends, name: "index_search_trends_on_tag_and_day_daily" if index_exists?(:search_trends, %i[tag day], name: "index_search_trends_on_tag_and_day_daily")
      remove_index :search_trends, name: "index_search_trends_on_all" if index_exists?(:search_trends, %i[tag day hour], name: "index_search_trends_on_all")

      # Remove the hour column since SearchTrend is now daily-only
      remove_column :search_trends, :hour
    end
  end

  def down
    SearchTrend.without_timeout do
      # Add back the hour column
      add_column :search_trends, :hour, :integer

      # Remove the daily-only index
      remove_index :search_trends, name: "index_search_trends_on_tag_and_day"
      remove_index :search_trends, name: "index_search_trends_on_tag_trigram"

      # Restore the partial indexes for mixed daily/hourly records
      add_index :search_trends, %i[tag day hour],
                unique: true,
                where: "hour IS NOT NULL",
                name: "index_search_trends_on_tag_day_hour"
      add_index :search_trends, %i[tag day],
                unique: true,
                where: "hour IS NULL",
                name: "index_search_trends_on_tag_and_day_daily"
      add_index :search_trends, %i[tag day hour], name: "index_search_trends_on_all"

      # Drop the hourly table
      drop_table :search_trend_hourlies
    end
  end
end
