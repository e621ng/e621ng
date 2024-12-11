# frozen_string_literal: true

class SoftDeletableStaffNotes < ActiveRecord::Migration[7.1]
  def change
    add_column :staff_notes, :is_deleted, :boolean, null: false, default: false
    add_reference :staff_notes, :updater, foreign_key: { to_table: :users }, null: false
    remove_column :staff_notes, :resolved, :boolean, null: false, default: false
  end
end
