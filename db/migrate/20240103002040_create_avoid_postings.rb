# frozen_string_literal: true

class CreateAvoidPostings < ActiveRecord::Migration[7.0]
  def change
    create_table(:avoid_postings) do |t|
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.references(:artist, foreign_key: true, null: false, index: { unique: true })
      t.inet(:creator_ip_addr, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.string(:details, null: false, default: "")
      t.string(:staff_notes, null: false, default: "")
      t.boolean(:is_active, null: false, default: true)
      t.timestamps
    end
  end
end
