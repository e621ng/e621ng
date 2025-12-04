# frozen_string_literal: true

class AddIndexCommentsOnCreatedAt < ActiveRecord::Migration[7.2]
  def change
    Comment.without_timeout do
      add_index :comments, %i[created_at id], order: { created_at: :desc, id: :desc }, name: :index_comments_on_created_at_desc
    end
  end
end
