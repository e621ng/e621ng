class PostCommentLocked < ActiveRecord::Migration[6.1]
  def change
    Post.without_timeout do
      add_column :posts, :is_comment_locked, :boolean, null: false, default: false
    end
  end
end
