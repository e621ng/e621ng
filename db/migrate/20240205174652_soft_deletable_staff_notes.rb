# frozen_string_literal: true

class SoftDeletableStaffNotes < ActiveRecord::Migration[7.1]
  def up
    add_column :staff_notes, :is_deleted, :boolean, null: false, default: false

    add_reference :staff_notes, :updater, foreign_key: { to_table: :users }, null: true
    execute("UPDATE staff_notes SET updater_id = creator_id")
    change_column_null :staff_notes, :updater_id, false

    remove_column :staff_notes, :resolved, :boolean, null: false, default: false
  end
end
