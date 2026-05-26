# frozen_string_literal: true

class AddBanFlagsToBans < ActiveRecord::Migration[8.1]
  def change
    add_column :bans, :ban_flags, :integer, null: false, default: 1
    change_column_default :bans, :ban_flags, from: 1, to: 0
  end
end
