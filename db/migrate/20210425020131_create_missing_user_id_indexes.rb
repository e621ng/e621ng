class CreateMissingUserIdIndexes < ActiveRecord::Migration[6.1]
  def change
    add_index :favorites, :user_id
    add_index :favorites, :post_id
    add_index :post_votes, :user_id
    add_index :post_votes, :post_id
    add_index :comments, :creator_id
  end
end
