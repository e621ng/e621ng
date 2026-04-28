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

      # Used to fetch historic trends for a specific tag
      add_index :search_trends, %i[tag day hour], name: "index_search_trends_on_all"
    end
  end

  def down
    SearchTrend.without_timeout do
      # Coalesce all hourly records into daily aggregates before removing the partial indexes.
      # Without this step, `index_search_trends_on_tag_and_day` would fail with a duplicate key error.
      execute(<<~SQL.squish)
        INSERT INTO search_trends (tag, day, hour, count, created_at, updated_at)
        SELECT tag, day, NULL, SUM(count)::integer, NOW(), NOW()
        FROM search_trends
        WHERE hour IS NOT NULL
        GROUP BY tag, day
        ON CONFLICT (tag, day) WHERE hour IS NULL
        DO UPDATE SET count      = search_trends.count + EXCLUDED.count,
                      updated_at = EXCLUDED.updated_at
      SQL
      execute("DELETE FROM search_trends WHERE hour IS NOT NULL")

      remove_index :search_trends, name: "index_search_trends_on_tag_day_hour"
      remove_index :search_trends, name: "index_search_trends_on_tag_and_day_daily"
      remove_index :search_trends, name: "index_search_trends_on_all"

      add_index :search_trends, %i[tag day], unique: true, name: "index_search_trends_on_tag_and_day"

      remove_column :search_trends, :hour
    end
  end
end
