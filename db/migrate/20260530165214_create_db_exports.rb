# frozen_string_literal: true

class CreateDbExports < ActiveRecord::Migration[8.1]
  def change
    create_table :db_exports do |t|
      t.string :name, null: false
      t.bigint :file_size, null: false, default: 0

      t.timestamps
    end

    add_index :db_exports, :name, unique: true
  end
end
