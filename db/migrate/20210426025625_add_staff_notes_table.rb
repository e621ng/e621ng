class AddStaffNotesTable < ActiveRecord::Migration[6.1]
  def change
    create_table :staff_notes do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :creator_id, null: false, index: true
      t.string :body
      t.boolean :resolved, null: false, default: false
    end
  end
end
