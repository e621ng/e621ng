class AddUserStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :user_statuses do |t|
      t.timestamps
      t.integer :user_id, index: true, null: false
      t.integer :post_count, null: false, default: 0
      t.integer :post_deleted_count, null: false, default: 0
      t.integer :post_update_count, null: false, default: 0
      t.integer :post_flag_count, null: false, default: 0
      t.integer :favorite_count, null: false, default: 0
      t.integer :wiki_edit_count, null: false, default: 0
      t.integer :note_count, null: false, default: 0
      t.integer :forum_post_count, null: false, default: 0
      t.integer :comment_count, null: false, default: 0
      t.integer :pool_edit_count, null: false, default: 0
      t.integer :blip_count, null: false, default: 0
      t.integer :set_count, null: false, default: 0
      t.integer :artist_edit_count, null: false, default: 0
    end
  end
end
