# frozen_string_literal: true

class CreateStaffWikis < ActiveRecord::Migration[7.1]
  def change
    # Staff Wiki
    create_table :staff_wikis do |t|
      t.integer :creator_id, null: false
      t.integer :updater_id, null: false
      t.integer :claimant_id
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end

    add_index :staff_wikis, "lower(title)", unique: true, name: "index_staff_wikis_on_lower_title"

    # Staff Wiki Version
    create_table :staff_wiki_versions do |t|
      t.integer :staff_wiki_id, null: false
      t.integer :updater_id, null: false
      t.integer :claimant_id
      t.column :updater_ip_addr, :inet, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end

    add_index :staff_wiki_versions, :staff_wiki_id
    add_index :staff_wiki_versions, :updater_id

    # Staff Wiki Refrences
    create_table :staff_wiki_refs do |t|
      t.integer :staff_wiki_id, null: false
      t.integer :related_id, null: false
      t.string :related_type, null: false
      t.timestamps
    end

    add_index :staff_wiki_refs, %i[related_id related_type]
  end
end
