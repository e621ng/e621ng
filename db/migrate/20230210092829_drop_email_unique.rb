# frozen_string_literal: true

class DropEmailUnique < ActiveRecord::Migration[7.0]
  def up
    remove_index :users, name: :index_users_on_email
    add_index :users, :email
  end
end
