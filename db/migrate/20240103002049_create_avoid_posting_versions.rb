# frozen_string_literal: true

class CreateAvoidPostingVersions < ActiveRecord::Migration[7.0]
  def change
    create_table(:avoid_posting_versions) do |t|
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.references(:avoid_posting, foreign_key: { to_table: :avoid_postings }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.string(:details, null: false, default: "")
      t.string(:staff_notes, null: false, default: "")
      t.boolean(:is_active, null: false, default: true)
      t.datetime(:updated_at, null: false)
    end
  end
end
