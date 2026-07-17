# frozen_string_literal: true

class CreatePostReplacementNotes < ActiveRecord::Migration[7.1]
  def change
    create_table :post_replacement_notes do |t|
      t.references :post_replacements2, null: false, foreign_key: { to_table: :post_replacements2 }
      t.text :note

      t.timestamps
    end
  end
end
