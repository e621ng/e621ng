# frozen_string_literal: true

class AddIndexPostsPoolStringTokens < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_posts_on_pool_string_tokens"

  def up
    # Create a GIN index on the tokenized pool_string so we can query for a specific token efficiently.
    # This enables queries like: string_to_array(pool_string, ' ') @> ARRAY['set:123']::text[]
    Post.without_timeout do
      add_index :posts,
                "string_to_array(pool_string, ' ')",
                using: :gin,
                name: INDEX_NAME,
                algorithm: :concurrently
    end
  end

  def down
    remove_index :posts, name: INDEX_NAME, algorithm: :concurrently
  end
end
