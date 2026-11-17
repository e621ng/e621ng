# frozen_string_literal: true

class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :secret_digest, null: false
      t.string :site, null: false
      t.boolean :remember, null: false, default: false
      t.text :user_agent
      t.inet :created_ip
      t.inet :last_ip
      t.datetime :last_seen_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :revoked_reason
      # Transition only (doc 42 §8.2): identifies the pre-rollout cookie a row was adopted from.
      t.string :legacy_key
      t.timestamps
    end

    add_index :user_sessions, :user_id, where: "revoked_at IS NULL", name: "index_user_sessions_on_user_id_active"
    add_index :user_sessions, %i[user_id legacy_key], where: "legacy_key IS NOT NULL"
    add_index :user_sessions, :expires_at
  end
end
