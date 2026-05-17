# frozen_string_literal: true

class AddSoftBans < ActiveRecord::Migration[8.1]
  def change
    # Default to true for existing ones, switch to true for new ones
    add_column :bans, :force_logout, :boolean, default: true, null: false
    change_column_default :bans, :force_logout, from: true, to: false
  end
end
