class CreateTagTypeVersions < ActiveRecord::Migration[5.2]
  def change
    create_table :tag_type_versions do |t|
      t.timestamps
      t.integer :old_type, null: false
      t.integer :new_type, null: false
      t.boolean :is_locked, null: false
      t.integer :tag_id, index: true, null: false
      t.integer :creator_id, index: true, null: false
    end
  end
end
