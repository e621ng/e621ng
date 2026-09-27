# frozen_string_literal: true

class AddSettingsRevisionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :settings_revision, :integer, null: false, default: 0
  end
end
