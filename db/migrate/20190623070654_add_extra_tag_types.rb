class AddExtraTagTypes < ActiveRecord::Migration[5.2]
  def change
    add_column :posts, :tag_count_species, :int, null: false, default: 0
    add_column :posts, :tag_count_invalid, :int, null: false, default: 0
  end
end
