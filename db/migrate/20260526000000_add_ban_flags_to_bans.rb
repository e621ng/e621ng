# frozen_string_literal: true

class AddBanFlagsToBans < ActiveRecord::Migration[8.1]
  def change
    add_column :bans, :ban_flags, :integer, null: false, default: 0
    # Migrate all existing bans to hard bans (PREVENT_LOGIN = 1) to preserve current behavior.
    Ban.update_all(ban_flags: 1)
  end
end
