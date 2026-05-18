# frozen_string_literal: true

class AddIndexPostsOnIsCommentDisabled < ActiveRecord::Migration[7.1]
  def change
    Post.without_timeout do
      add_index :posts, :id, where: "is_comment_disabled = true", name: "index_posts_on_is_comment_disabled"
      add_index :comments, :id, where: "is_sticky = true", name: "index_comments_on_is_sticky"
      add_index :comments, :id, where: "is_hidden = true", name: "index_comments_on_is_hidden"
    end
  end
end
