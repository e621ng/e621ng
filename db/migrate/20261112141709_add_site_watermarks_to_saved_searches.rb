# frozen_string_literal: true

# Profile site id => post id (doc 38). The primary site's watermark stays in last_seen_post_id.
class AddSiteWatermarksToSavedSearches < ActiveRecord::Migration[8.1]
  def change
    add_column :saved_searches, :site_watermarks, :jsonb, default: {}, null: false
  end
end
