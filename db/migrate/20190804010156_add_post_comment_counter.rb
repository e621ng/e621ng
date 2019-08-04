class AddPostCommentCounter < ActiveRecord::Migration[5.2]
  def change
    add_column :posts, :comment_count, :integer, null: false, default: 0
  end
end
