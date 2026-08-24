# frozen_string_literal: true

class CreateUploadKarmaEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :upload_karma_events do |t|
      t.bigint :user_id, null: false
      t.bigint :creator_id, null: false
      t.bigint :post_id
      t.integer :reason, null: false
      t.integer :delta, null: false
      t.integer :balance, null: false
      t.jsonb :extra_data, null: false, default: {}
      t.datetime :created_at, null: false

      t.index %i[user_id id]
      t.index :post_id, where: "post_id IS NOT NULL"
    end
  end
end
