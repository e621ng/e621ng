# frozen_string_literal: true

class RemoveDeadTablesAndColumns < ActiveRecord::Migration[6.1]
  def up
    User.without_timeout do
      drop_table :post_appeals
      drop_table :favorite_groups
      drop_table :post_image_hashes
      drop_table :post_replacements
      drop_table :saved_searches
      drop_table :user_blacklisted_tags
      drop_table :post_updates
      drop_table :pixiv_ugoira_frame_data
      remove_column :artists, :is_banned
      remove_column :artist_versions, :is_banned
      remove_column :forum_topics, :min_level
      remove_column :dmails, :is_spam
      remove_column :posts, :pixiv_id
      remove_column :uploads, :referer_url
      remove_column :uploads, :context
      remove_column :uploads, :content_type
      remove_column :uploads, :file_path
      remove_column :uploads, :server
      change_column_null :users, :profile_about, false
      change_column_null :users, :profile_artinfo, false
    end
  end
end
