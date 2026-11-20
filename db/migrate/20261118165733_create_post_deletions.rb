# frozen_string_literal: true

# Schema only; the data is copied out of post_flags by db/fixes/146_backfill_post_deletions.rb.
class CreatePostDeletions < ActiveRecord::Migration[8.1]
  def change
    create_table :post_deletions do |t|
      t.integer :post_id, null: false
      t.integer :deleter_id, null: false
      t.integer :undeleter_id
      t.inet :creator_ip_addr, null: false
      t.text :reason, null: false
      t.boolean :is_undeleted, null: false, default: false
      t.integer :source_post_flag_id
      t.datetime :created_at, null: false
      t.datetime :undeleted_at
    end

    add_index :post_deletions, :post_id, unique: true, where: "is_undeleted = false", name: "index_post_deletions_active_unique"
    add_index :post_deletions, %i[post_id id]
    add_index :post_deletions, :deleter_id
    add_index :post_deletions, :creator_ip_addr
    add_index :post_deletions, :source_post_flag_id, unique: true
    add_index :post_deletions, :created_at
    add_index :post_deletions, "to_tsvector('english'::regconfig, reason)", using: :gin, name: "index_post_deletions_on_reason_tsvector"

    add_foreign_key :post_deletions, :posts, column: :post_id, on_delete: :cascade
    add_foreign_key :post_deletions, :users, column: :deleter_id
    add_foreign_key :post_deletions, :users, column: :undeleter_id
  end
end
