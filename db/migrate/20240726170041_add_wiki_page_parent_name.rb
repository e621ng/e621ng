# frozen_string_literal: true

class AddWikiPageParentName < ActiveRecord::Migration[7.0]
  def change
    add_column :wiki_pages, :parent, :string
    add_column :wiki_page_versions, :parent, :string
  end
end
