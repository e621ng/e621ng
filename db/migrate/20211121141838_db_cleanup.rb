class DbCleanup < ActiveRecord::Migration[6.1]
  def down
    drop_table :artist_commentaries
    drop_table :artist_commentary_versions
    drop_table :favorite_groups
    drop_table :post_appeals
    drop_table :post_image_hashes
    drop_table :post_replacements
    drop_table :saved_searches
    drop_table :pixiv_ugoira_frame_data
    drop_table :user_blacklisted_tags
    drop_table :post_updates

    rename_table :post_replacements2, :post_replacements

    change_table :uploads, bulk: true do |t|
      t.remove :artist_commentary_desc
      t.remove :artist_commentary_title
      t.remove :include_artist_commentary
      t.remove :referer_url
      t.remove :server
      t.remove :context
      t.remove :content_type
    end
    remove_column :artists, :group_name
    remove_column :artist_versions, :group_name
    remove_column :dmails, :is_spam
  end
end
