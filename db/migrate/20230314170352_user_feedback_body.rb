# frozen_string_literal: true

class UserFeedbackBody < ActiveRecord::Migration[7.0]
  def change
    add_index :user_feedback, "to_tsvector('english', body)", using: :gin
  end
end
