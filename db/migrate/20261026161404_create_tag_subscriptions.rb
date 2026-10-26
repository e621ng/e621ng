# frozen_string_literal: true

class CreateTagSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :tag, null: false, foreign_key: true, type: :integer
      t.datetime :created_at, null: false

      t.index %i[user_id tag_id], unique: true
    end
  end
end
