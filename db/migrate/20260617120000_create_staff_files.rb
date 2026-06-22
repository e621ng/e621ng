# frozen_string_literal: true

class CreateStaffFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_files do |t|
      t.integer :creator_id, null: false
      t.string  :storage_id, null: false
      t.string  :md5, null: false
      t.string  :file_ext, null: false
      t.integer :file_size, null: false
      t.string  :original_filename, null: false
      t.string  :title
      t.text    :description
      t.timestamps
    end

    add_foreign_key :staff_files, :users, column: :creator_id

    add_index :staff_files, :storage_id, unique: true
    add_index :staff_files, :creator_id
    add_index :staff_files, :md5
  end
end
