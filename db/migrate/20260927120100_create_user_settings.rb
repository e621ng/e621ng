# frozen_string_literal: true

class CreateUserSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :user_settings, id: false do |t|
      t.bigint :user_id, null: false, primary_key: true
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end

    add_foreign_key :user_settings, :users, column: :user_id
  end
end
