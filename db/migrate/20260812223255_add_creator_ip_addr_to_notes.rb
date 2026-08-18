# frozen_string_literal: true

# Prod has notes.creator_ip_addr (inet NOT NULL) but structure.sql lost it somewhere along the way.
class AddCreatorIpAddrToNotes < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:notes, :creator_ip_addr)

    Note.without_timeout do
      add_column :notes, :creator_ip_addr, :inet
      execute("UPDATE notes SET creator_ip_addr = '127.0.0.1' WHERE creator_ip_addr IS NULL")
      change_column_null :notes, :creator_ip_addr, false
    end
  end

  def down
    # Prod always had this column; removing it would discard recorded data.
  end
end
