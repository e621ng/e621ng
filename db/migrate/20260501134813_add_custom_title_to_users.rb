# frozen_string_literal: true

class AddCustomTitleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :custom_title, :string, null: false, default: ""
  end
end
