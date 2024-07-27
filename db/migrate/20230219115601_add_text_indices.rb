# frozen_string_literal: true

class AddTextIndices < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_gin_index :blips, "to_tsvector('english', body)"
    add_gin_index :comments, "to_tsvector('english', body)"
    add_gin_index :dmails, "to_tsvector('english', body)"
    add_gin_index :forum_posts, "to_tsvector('english', body)"
    add_gin_index :forum_topics, "to_tsvector('english', title)"
    add_gin_index :notes, "to_tsvector('english', body)"
    add_gin_index :wiki_pages, "to_tsvector('english', body)"
    add_gin_index :posts, "string_to_array(tag_string, ' ')"
    up_only do
      execute "ALTER INDEX index_posts_on_string_to_array_tag_string ALTER COLUMN 1 SET STATISTICS 3000"
    end
  end

  def add_gin_index(table, index)
    add_index table, "(#{index})", using: :gin, algorithm: :concurrently
  end
end
