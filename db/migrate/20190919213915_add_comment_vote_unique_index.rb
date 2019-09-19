class AddCommentVoteUniqueIndex < ActiveRecord::Migration[6.0]
  def change
    add_index :comment_votes, [:comment_id, :user_id], unique: true
  end
end
