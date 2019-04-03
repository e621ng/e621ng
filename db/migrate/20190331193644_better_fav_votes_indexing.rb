class BetterFavVotesIndexing < ActiveRecord::Migration[5.2]
  def change
    remove_index :favorites, :user_id
    remove_index :favorites, :post_id
    remove_index :post_votes, :user_id
    remove_index :post_votes, :post_id
    add_index :favorites, [:user_id, :post_id], unique: true
    add_index :post_votes, [:user_id, :post_id], unique: true
  end
end
