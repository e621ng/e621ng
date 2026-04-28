# frozen_string_literal: true

class AddIndexPostsOnApproverId < ActiveRecord::Migration[8.0]
  def change
    Post.without_timeout do
      add_index :posts, :approver_id
    end
  end
end
