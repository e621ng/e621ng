# frozen_string_literal: true

class CreateAutomodRules < ActiveRecord::Migration[7.1]
  def change
    create_table :automod_rules do |t|
      t.string :name, null: false
      t.text :description
      t.text :regex, null: false
      t.boolean :enabled, null: false, default: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :automod_rules, :name, unique: true
  end
end
