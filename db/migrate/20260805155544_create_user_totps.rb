# frozen_string_literal: true

class CreateUserTotps < ActiveRecord::Migration[8.1]
  def change
    create_table :user_totps do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :secret_ciphertext, null: false
      t.text :backup_code_digests, array: true, null: false, default: []
      t.bigint :last_used_step
      t.timestamps
    end
  end
end
