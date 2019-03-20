class CreatePostSets < ActiveRecord::Migration[5.2]
  def change
    create_table :post_sets do |t|
      t.string :name, null: false
      t.string :shortname, null: false
      t.text :description, default: ''
      t.boolean :is_public, null: false, default: false
      t.boolean :transfer_on_delete, null: false, default: false
      t.integer :creator_id, null: false
      t.column :creator_ip_addr, 'inet', null: true
      t.column :post_ids, 'integer[]', null: false, default: '{}'
      t.integer :post_count, null: false, default: 0
      t.timestamps
    end

    create_table :post_set_maintainers do |t|
      t.integer :post_set_id, null: false
      t.integer :user_id, null: false
      t.string :status, null: false, default: 'pending'
      t.timestamps
    end

    add_column :users, :set_count, :integer, null: false, default: 0
  end
end
