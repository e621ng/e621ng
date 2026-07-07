# frozen_string_literal: true

class AddFeaturedPostsToWikiPages < ActiveRecord::Migration[8.1]
  def change
    add_column :wiki_pages, :featured_posts, :integer, array: true, default: [], null: false
    add_column :wiki_page_versions, :featured_posts, :integer, array: true, default: [], null: false
  end
end
