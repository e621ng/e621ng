class DropUnusedPostIndexes < ActiveRecord::Migration[6.0]
  def change
    execute "drop index if exists index_posts_on_source"
    remove_index :posts, :image_height
    remove_index :posts, :image_width
    remove_index :posts, :file_size
    execute "drop index if exists index_posts_on_mpixels"
    remove_index :posts, :last_comment_bumped_at
    remove_index :posts, :last_noted_at
  end
end
