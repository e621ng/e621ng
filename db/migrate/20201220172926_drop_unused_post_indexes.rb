class DropUnusedPostIndexes < ActiveRecord::Migration[6.0]
  def up
    execute "drop index if exists index_posts_on_source"
    execute "drop index if exists index_posts_on_source_pattern"
    remove_index :posts, :image_height
    remove_index :posts, :image_width
    remove_index :posts, :file_size
    execute "drop index if exists index_posts_on_mpixels"
    remove_index :posts, :last_comment_bumped_at
    remove_index :posts, :last_noted_at
  end

  def down
    execute "CREATE INDEX IF NOT EXISTS index_posts_on_source ON posts USING btree
             (lower(source))"
    execute "CREATE INDEX IF NOT EXISTS index_posts_on_source_pattern ON posts USING btree
             ((SourcePattern(lower(source))) text_pattern_ops)"
    add_index :posts, :image_height
    add_index :posts, :image_width
    add_index :posts, :file_size
    add_index :posts, :last_comment_bumped_at
    add_index :posts, :last_noted_at
  end
end
