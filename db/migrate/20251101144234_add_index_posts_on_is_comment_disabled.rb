# frozen_string_literal: true

class AddIndexPostsOnIsCommentDisabled < ActiveRecord::Migration[7.1]
  def change
    add_index :posts, :id, where: "is_comment_disabled = true", name: "index_posts_on_is_comment_disabled"
  end
end
