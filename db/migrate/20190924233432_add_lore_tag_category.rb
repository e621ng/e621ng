class AddLoreTagCategory < ActiveRecord::Migration[6.0]
  def change
    add_column :posts, :tag_count_lore, :int, null: false, default: 0
  end
end
