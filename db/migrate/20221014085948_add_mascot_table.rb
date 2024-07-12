# frozen_string_literal: true

class AddMascotTable < ActiveRecord::Migration[6.1]
  def change
    create_table :mascots do |t|
      t.references :creator, foreign_key: { to_table: :users }, null: false
      t.string :display_name, null: false
      t.string :md5, index: { unique: true }, null: false
      t.string :file_ext, null: false
      t.string :background_color, null: false
      t.string :artist_url, null: false
      t.string :artist_name, null: false
      t.boolean :safe_mode_only, default: false, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
  end
end
