# frozen_string_literal: true

class CreatePostFlagReasons < ActiveRecord::Migration[6.1]
  def change
    create_table :post_flag_reasons do |t|
      t.string :name, null: false
      t.string :reason, null: false
      t.text :text, null: false, default: ""

      t.boolean :needs_explanation, null: false, default: false
      t.boolean :needs_parent_id, null: false, default: false

      t.string :type, null: false, default: "flag"
      t.integer :index, null: false, default: 0

      t.timestamps
    end

    add_index :post_flag_reasons, :name, unique: true
    add_index :post_flag_reasons, :index
    add_index :post_flag_reasons, :type
  end
end
