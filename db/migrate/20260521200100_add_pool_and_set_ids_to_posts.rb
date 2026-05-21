# frozen_string_literal: true

class AddPoolAndSetIdsToPosts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Post.without_timeout do
      add_column :posts, :pool_ids, :integer, array: true
      add_column :posts, :set_ids, :bigint, array: true

      add_index :posts, :pool_ids, using: :gin, algorithm: :concurrently
      add_index :posts, :set_ids, using: :gin, algorithm: :concurrently
    end
  end

  def down
    Post.without_timeout do
      remove_index :posts, :pool_ids, algorithm: :concurrently
      remove_index :posts, :set_ids, algorithm: :concurrently

      remove_column :posts, :pool_ids
      remove_column :posts, :set_ids
    end
  end
end
