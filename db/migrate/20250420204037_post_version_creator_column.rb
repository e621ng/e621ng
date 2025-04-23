# frozen_string_literal: true

class PostVersionCreatorColumn < ActiveRecord::Migration[7.1]
  def up
    PostVersion.without_timeout do
      rename_column :post_versions, :updater_id, :creator_id
      rename_column :post_versions, :updater_ip_addr, :creator_ip_addr
      rename_column :post_versions, :updated_at, :created_at

      change_column :post_versions, :creator_id, :integer, default: 0
      change_column :post_versions, :creator_ip_addr, :inet, default: "127.0.0.1"
      change_column :post_versions, :created_at, :datetime, default: -> { "now()" }

      add_column :post_versions, :updater_id, :integer, default: 0
      add_column :post_versions, :updater_ip_addr, :inet, default: "127.0.0.1"
      add_column :post_versions, :updated_at, :datetime, default: -> { "now()" }
    end
  end

  def down
    PostVersion.without_timeout do
      remove_column :post_versions, :updater_id
      remove_column :post_versions, :updater_ip_addr
      remove_column :post_versions, :updated_at

      rename_column :post_versions, :creator_id, :updater_id
      rename_column :post_versions, :creator_ip_addr, :updater_ip_addr
      rename_column :post_versions, :created_at, :updated_at

      change_column :post_versions, :updater_id, :integer
      change_column :post_versions, :updater_ip_addr, :inet, null: false
      change_column :post_versions, :updated_at, :datetime
    end
  end
end
