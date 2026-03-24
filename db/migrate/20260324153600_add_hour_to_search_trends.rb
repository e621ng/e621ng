# frozen_string_literal: true

class AddHourToSearchTrends < ActiveRecord::Migration[7.2]
  def up
    SearchTrend.without_timeout do
      add_column :search_trends, :hour, :integer

      # Replace the single unique index with two partial unique indexes:
      # one for daily aggregate records (hour IS NULL) and one for hourly records.
      remove_index :search_trends, name: "index_search_trends_on_tag_and_day"

      add_index :search_trends, %i[tag day],
                unique: true,
                where: "hour IS NULL",
                name: "index_search_trends_on_tag_and_day_daily"

      add_index :search_trends, %i[tag day hour],
                unique: true,
                where: "hour IS NOT NULL",
                name: "index_search_trends_on_tag_day_hour"
    end
  end

  def down
    SearchTrend.without_timeout do
      remove_index :search_trends, name: "index_search_trends_on_tag_day_hour"
      remove_index :search_trends, name: "index_search_trends_on_tag_and_day_daily"

      add_index :search_trends, %i[tag day], unique: true, name: "index_search_trends_on_tag_and_day"

      remove_column :search_trends, :hour
    end
  end
end
