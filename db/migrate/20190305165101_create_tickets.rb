class CreateTickets < ActiveRecord::Migration[5.2]
  def change
    create_table :tickets do |t|
      t.integer :creator_id, null: false
      t.column :creator_ip_addr, "inet", null: false
      t.integer :disp_id, null: false
      t.string :qtype, null: false
      t.string :status, null: false, default: "pending"
      t.string :reason
      t.string :report_reason
      t.string :response, null: false, default: ''
      t.integer :handler_id, null: false, default: 0
      t.integer :claimant_id

      t.timestamps
    end
  end
end
