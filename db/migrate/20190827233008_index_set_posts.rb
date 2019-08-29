class IndexSetPosts < ActiveRecord::Migration[5.2]
  def up
    execute "CREATE INDEX index_post_sets_on_post_ids ON post_sets USING gin (post_ids)"
  end

  def down
    remove_index :post_sets, :post_ids
  end
end
