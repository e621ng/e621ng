class CreateNewReplacementsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :post_replacements2 do |t|
      t.timestamps
      t.integer :post_id, null: false
      t.integer :creator_id, null: false
      t.inet :creator_ip_addr, null: false
      t.integer :approver_id
      t.string :file_ext, length: 8, null: false
      t.integer :file_size, null: false
      t.integer :image_height, null: false
      t.integer :image_width, null: false
      t.string :md5, null: false
      t.string :source
      t.string :file_name, length: 512
      t.string :storage_id, null: false
      t.string :status, null: false, default: 'pending'
      t.string :reason, null: false, length: 500
      t.boolean :protected, null: false, default: false
    end

    add_index :post_replacements2, :creator_id
    add_index :post_replacements2, :post_id
  end
end
