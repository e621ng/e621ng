# frozen_string_literal: true

class CreateUserIpTouchesAndStats < ActiveRecord::Migration[8.1]
  def up
    create_table :user_ip_touches do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.inet :ip_addr, null: false
      t.string :source, null: false
      t.datetime :last_seen_at, null: false
      t.integer :hit_count, null: false, default: 1
      t.timestamps
    end
    add_index :user_ip_touches,
              %i[user_id ip_addr source],
              unique: true,
              name: "index_user_ip_touches_on_user_and_ip_and_source"
    add_index :user_ip_touches, :ip_addr

    create_table :ip_addr_stats, id: false do |t|
      t.inet :ip_addr, null: false
      t.integer :distinct_user_count, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    execute "ALTER TABLE ip_addr_stats ADD PRIMARY KEY (ip_addr)"
    add_index :ip_addr_stats, :distinct_user_count

    create_table :user_ip_touch_cursors, id: false do |t|
      t.string :source, null: false
      t.bigint :last_processed_id
      t.datetime :last_processed_at
      t.datetime :cutoff_at, null: false
      t.timestamps
    end
    execute "ALTER TABLE user_ip_touch_cursors ADD PRIMARY KEY (source)"
  end

  def down
    drop_table :user_ip_touch_cursors
    drop_table :ip_addr_stats
    drop_table :user_ip_touches
  end
end
