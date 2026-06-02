# frozen_string_literal: true

class CreateStaffWikis < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_wikis do |t|
      t.integer :creator_id, null: false
      t.integer :updater_id, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.timestamps
    end

    add_index :staff_wikis, "lower(title)", unique: true, name: "index_staff_wikis_on_lower_title"
  end
end
