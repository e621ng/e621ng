# frozen_string_literal: true

class AddPostEventsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :post_events do |t|
      t.references :creator, foreign_key: { to_table: :users }, null: false
      t.references :post, null: false
      t.integer :action, null: false
      t.jsonb :extra_data, null: false
      t.datetime :created_at, null: false
    end
  end
end
