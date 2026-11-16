# frozen_string_literal: true

class CreateUploadUrlRules < ActiveRecord::Migration[8.1]
  def change
    create_table :upload_url_rules do |t|
      t.string :label, null: false
      t.string :pattern, null: false
      t.string :replacement, null: false, default: ""
      t.string :message, null: false, default: ""
      t.string :handling, null: false
      t.boolean :enabled, null: false, default: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :updater, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :upload_url_rules, "lower(label)", unique: true, name: "index_upload_url_rules_on_lower_label"
  end
end
