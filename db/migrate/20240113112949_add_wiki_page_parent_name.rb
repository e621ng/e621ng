class AddWikiPageParentName < ActiveRecord::Migration[7.0]
  def change
    add_column :wiki_pages, :parent, :string
  end
end
