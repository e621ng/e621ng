# frozen_string_literal: true

class CreateUserIpAddresses < ActiveRecord::Migration[8.1]
  def change
    # Timestamps are domain columns (first_seen_at/last_seen_at), not created/updated_at.
    create_table :user_ip_addresses do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :user, null: false, foreign_key: true
      t.inet :ip_addr, null: false
      # Masked network, maintained by the database so it can never drift from
      # ip_addr: /24 for IPv4, /64 for IPv6.
      t.virtual :subnet, type: :inet, stored: true, null: false, as: <<~SQL.squish
        CASE WHEN family(ip_addr) = 4
             THEN network(set_masklen(ip_addr, 24))
             ELSE network(set_masklen(ip_addr, 64))
        END
      SQL
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.integer :hit_count, null: false, default: 1
    end

    # Doubles as the "all IPs of user X" lookup and the upsert conflict target.
    add_index :user_ip_addresses, %i[user_id ip_addr], unique: true
    # user_id trails the value so COUNT(DISTINCT user_id) GROUP BY value stays
    # index-only on crowded values (CGNAT/VPN pools).
    add_index :user_ip_addresses, %i[ip_addr user_id]
    add_index :user_ip_addresses, %i[subnet user_id]
    add_index :user_ip_addresses, :last_seen_at
  end
end
