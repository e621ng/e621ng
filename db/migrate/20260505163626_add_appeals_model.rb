# frozen_string_literal: true

class AddAppealsModel < ActiveRecord::Migration[8.1]
  def change
    create_table :appeals do |t|
      t.integer :creator_id, null: false
      t.inet :creator_ip_addr, null: false
      t.integer :disp_id, null: false
      t.string :qtype, null: false
      t.string :status, null: false, default: "pending"
      t.text :reason, null: false
      t.text :response, null: false, default: ""
      t.integer :claimant_id
      t.integer :handler_id
      t.integer :accused_id
      t.timestamps
    end

    add_foreign_key :appeals, :users, column: :creator_id
    add_foreign_key :appeals, :users, column: :claimant_id
    add_foreign_key :appeals, :users, column: :handler_id
    add_foreign_key :appeals, :users, column: :accused_id
  end
end
