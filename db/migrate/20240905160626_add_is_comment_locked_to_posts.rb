# frozen_string_literal: true

class AddIsCommentLockedToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column(:posts, :is_comment_locked, :boolean, null: false, default: false)
  end
end
