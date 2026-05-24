# frozen_string_literal: true

class AddAppMetadataToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :description, :text
    add_column :oauth_applications, :homepage_url, :string
    add_column :oauth_applications, :minimum_user_level, :integer, null: false, default: 0
  end
end
