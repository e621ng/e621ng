# frozen_string_literal: true

class CreateStaffWikiVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_wiki_versions do |t|
      t.integer :staff_wiki_id, null: false
      t.integer :updater_id, null: false
      t.column :updater_ip_addr, :inet, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.string :reason
      t.timestamps
    end

    add_index :staff_wiki_versions, :staff_wiki_id
    add_index :staff_wiki_versions, :updater_id
  end
end
