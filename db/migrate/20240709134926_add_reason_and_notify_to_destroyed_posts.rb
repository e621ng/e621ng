# frozen_string_literal: true

class AddReasonAndNotifyToDestroyedPosts < ActiveRecord::Migration[7.1]
  def change
    add_column(:destroyed_posts, :reason, :string, null: false, default: "")
    add_column(:destroyed_posts, :notify, :boolean, null: false, default: true)
  end
end
