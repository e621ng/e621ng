# frozen_string_literal: true

class AddForeignKeysToVotes < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key(:comment_votes, :comments, column: :comment_id)
    add_foreign_key(:comment_votes, :users, column: :user_id)
    add_foreign_key(:post_votes, :posts, column: :post_id)
    add_foreign_key(:post_votes, :users, column: :user_id)
  end
end
