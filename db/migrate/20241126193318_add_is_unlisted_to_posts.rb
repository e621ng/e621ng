# frozen_string_literal: true

class AddIsUnlistedToPosts < ActiveRecord::Migration[7.1]
  def change
    add_column(:posts, :is_unlisted, :boolean, null: false, default: false)
  end
end
