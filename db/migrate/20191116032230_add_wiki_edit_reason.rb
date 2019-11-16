class AddWikiEditReason < ActiveRecord::Migration[6.0]
  def change
    add_column :wiki_page_versions, :reason, :string, null: true
  end
end
