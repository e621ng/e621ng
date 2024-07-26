# frozen_string_literal: true

class AddIsDeletedToUserFeedback < ActiveRecord::Migration[7.1]
  def change
    add_column(:user_feedback, :is_deleted, :boolean, null: false, default: false)
  end
end
