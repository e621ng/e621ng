# frozen_string_literal: true

class CreateDoorkeeperTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_applications do |t|
      t.string :name, null: false
      t.string :uid, null: false
      t.string :secret, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.references :owner, polymorphic: true, null: true
      t.text :description
      t.string :homepage_url
      t.integer :minimum_user_level, null: false, default: 0
      t.timestamps
    end

    add_index :oauth_applications, :uid, unique: true

    create_table :oauth_access_grants do |t|
      t.references :resource_owner, null: false, foreign_key: { to_table: :users }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.string :token, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.datetime :revoked_at
      t.string :code_challenge
      t.string :code_challenge_method
      t.timestamps
    end

    add_index :oauth_access_grants, :token, unique: true

    create_table :oauth_access_tokens do |t|
      t.references :resource_owner, index: true, foreign_key: { to_table: :users }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications }
      t.string :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.string :scopes
      t.datetime :revoked_at
      t.string :previous_refresh_token, null: false, default: ""
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :refresh_token, unique: true

    create_table :oauth_openid_requests do |t| # rubocop:disable Rails/CreateTableWithTimestamps
      t.references :access_grant, null: false, foreign_key: { to_table: :oauth_access_grants, on_delete: :cascade }
      t.string :nonce, null: false
    end
  end
end
