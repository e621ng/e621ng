# frozen_string_literal: true

class AddOrderingIndexesToForumPosts < ActiveRecord::Migration[8.1]
  def change
    ForumPost.without_timeout do
      add_index(:forum_posts, :created_at)
      add_index(:forum_posts, :updated_at)
    end
  end
end
