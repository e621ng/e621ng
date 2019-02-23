class CreateTakedowns < ActiveRecord::Migration[5.2]
  def change
    create_table :takedowns do |t|
      t.timestamps
      t.integer :creator_id, null: true
      t.column :creator_ip_addr, :inet, null: false
      t.integer :approver_id
      t.string :status, default: 'pending'
      t.string :vericode, null: false
      t.string :source
      t.string :email
      t.text :reason
      t.boolean :reason_hidden, null: false, default: false
      t.text :notes, default: 'none', null: false
      t.text :instructions
      t.text :post_ids, default: ''
      t.text :del_post_ids, default: ''
      t.integer :post_count, default: 0, null: false
    end
  end
end
