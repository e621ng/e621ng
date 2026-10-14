# frozen_string_literal: true

class AddPoolIdsToPosts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Post.without_timeout do
      # The column must be added without a default: existing rows stay NULL,
      # which marks them as not yet backfilled (see db/fixes/141).
      add_column :posts, :pool_ids, :integer, array: true
      change_column_default :posts, :pool_ids, "{}"

      add_index :posts, :pool_ids, using: :gin, algorithm: :concurrently
    end
  end

  def down
    Post.without_timeout do
      remove_index :posts, :pool_ids, algorithm: :concurrently
      remove_column :posts, :pool_ids
    end
  end
end
