class DropUnusedModActionFields < ActiveRecord::Migration[6.1]
  def up
    remove_column :mod_actions, :category
    remove_column :mod_actions, :description
  end

  def down
    add_column :mod_actions, :category, :text
    add_column :mod_actions, :description, :integer
  end
end
