# frozen_string_literal: true

class AddIndexUsersOnLastLogin < ActiveRecord::Migration[8.0]
  def change
    User.without_timeout do
      add_index :users, :last_logged_in_at
    end
  end
end
