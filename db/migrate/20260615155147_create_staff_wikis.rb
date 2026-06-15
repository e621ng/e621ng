# frozen_string_literal: true

class CreateStaffWikis < ActiveRecord::Migration[7.1]
  def change
    # Staff Wiki
    create_table :staff_wikis do |t|
      t.integer :creator_id, null: false
      t.integer :updater_id, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.timestamps

      t.string :qtype, null: false, default: "general"
      t.integer :related_id
      t.integer :claimant_id
    end

    add_index :staff_wikis, "lower(title)", unique: true, name: "index_staff_wikis_on_lower_title"

    # Staff Wiki Version
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
