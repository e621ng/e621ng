# frozen_string_literal: true

class FavoriteEvent < ApplicationRecord
  RETENTION_DAYS = 14
  LOOKAHEAD_DAYS = 7

  def self.ensure_upcoming_partitions!(days_ahead: LOOKAHEAD_DAYS)
    (0..days_ahead).each { |i| create_partition!(Time.zone.today + i) }
  end

  def self.drop_old_partitions!(retention_days: RETENTION_DAYS)
    cutoff_name = "favorite_events_#{(Time.zone.today - retention_days).strftime('%Y_%m_%d')}"
    partitions = connection.exec_query(<<~SQL.squish).pluck("relname")
      SELECT c.relname
      FROM pg_class c
      JOIN pg_inherits i ON c.oid = i.inhrelid
      JOIN pg_class p ON i.inhparent = p.oid
      WHERE p.relname = 'favorite_events'
        AND c.relname < '#{connection.quote_string(cutoff_name)}'
      ORDER BY c.relname
    SQL
    partitions.each { |name| connection.execute("DROP TABLE IF EXISTS public.#{connection.quote_column_name(name)}") }
  end

  private_class_method def self.create_partition!(date)
    from = date.strftime("%Y-%m-%d")
    to   = (date + 1).strftime("%Y-%m-%d")
    name = "favorite_events_#{date.strftime('%Y_%m_%d')}"
    connection.execute("CREATE TABLE IF NOT EXISTS public.#{name} PARTITION OF public.favorite_events FOR VALUES FROM ('#{from}') TO ('#{to}')")
  end
end
