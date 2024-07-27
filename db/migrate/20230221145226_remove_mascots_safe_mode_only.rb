# frozen_string_literal: true

class RemoveMascotsSafeModeOnly < ActiveRecord::Migration[7.0]
  def change
    remove_column :mascots, :safe_mode_only, type: :boolean, default: false, null: false
  end
end
