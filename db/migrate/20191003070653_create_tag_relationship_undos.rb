class CreateTagRelationshipUndos < ActiveRecord::Migration[6.0]
  def change
    create_table :tag_rel_undos do |t|
      t.references :tag_rel, polymorphic: true
      t.json :undo_data
      t.boolean :applied, default: false
      t.timestamps
    end
  end
end
