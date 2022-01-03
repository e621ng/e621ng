class UserStatusAddIndices < ActiveRecord::Migration[6.1]
  def change
    change_table :user_statuses do |t|
      t.index :post_count
      t.index :post_update_count
      t.index :note_count
      t.index :wiki_edit_count
      t.index :artist_edit_count
      t.index :pool_edit_count
      t.index :forum_post_count
      t.index :comment_count
    end
  end
end
