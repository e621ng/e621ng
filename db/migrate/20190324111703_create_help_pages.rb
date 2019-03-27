class CreateHelpPages < ActiveRecord::Migration[5.2]
  def change
    create_table :help_pages do |t|
      t.timestamps
      t.string :name, null: false
      t.string :wiki_page, null: false
      t.string :related
      t.string :title
    end
  end
end
