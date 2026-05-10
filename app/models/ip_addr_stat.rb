# frozen_string_literal: true

class IpAddrStat < ApplicationRecord
  self.primary_key = "ip_addr"

  validates :distinct_user_count, :last_seen_at, presence: true

  def self.recompute_for!(ip_addrs)
    ips = Array(ip_addrs).compact.uniq
    return if ips.empty?

    connection.execute(sanitize_sql([<<~SQL.squish, ips]))
      INSERT INTO ip_addr_stats (ip_addr, distinct_user_count, last_seen_at, created_at, updated_at)
      SELECT ip_addr, COUNT(DISTINCT user_id), MAX(last_seen_at), NOW(), NOW()
      FROM user_ip_touches
      WHERE ip_addr = ANY(ARRAY[?]::inet[])
      GROUP BY ip_addr
      ON CONFLICT (ip_addr) DO UPDATE SET
        distinct_user_count = EXCLUDED.distinct_user_count,
        last_seen_at = EXCLUDED.last_seen_at,
        updated_at = NOW()
    SQL
  end
end
