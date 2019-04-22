class CreateForumCategories < ActiveRecord::Migration[5.2]
  def change
    create_table :forum_categories do |t|
      t.string :name, null: false
      t.text :description
      t.integer :cat_order
      t.integer :can_view, default: 20, null: false
      t.integer :can_create, default: 20, null: false
      t.integer :can_reply, default: 20, null: false
    end
  end
end
