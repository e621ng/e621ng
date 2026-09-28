# frozen_string_literal: true

class CreateFavoriteFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :favorite_folders do |t|
      t.integer :user_id, null: false
      t.bigint  :parent_id
      t.string  :name, null: false
      t.timestamps
    end

    add_foreign_key :favorite_folders, :users, column: :user_id
    add_foreign_key :favorite_folders, :favorite_folders, column: :parent_id

    add_index :favorite_folders, :user_id
    add_index :favorite_folders, :parent_id

    # Case-insensitive sibling-name uniqueness. Two separate partial unique
    # indexes are required instead of one plain (user_id, parent_id, lower(name))
    # index: Postgres compares NULLs in an indexed column as distinct from each
    # other, so a single index would never catch two root-level folders
    # (parent_id IS NULL for all of them) with the same lower(name). The root
    # index below excludes parent_id from its key entirely (only as a WHERE
    # filter), sidestepping that NULL-vs-NULL comparison altogether.
    add_index :favorite_folders, "user_id, parent_id, lower(name)",
              unique: true,
              name: "index_favorite_folders_on_user_parent_lower_name",
              where: "parent_id IS NOT NULL"
    add_index :favorite_folders, "user_id, lower(name)",
              unique: true,
              name: "index_favorite_folders_on_user_lower_name_root",
              where: "parent_id IS NULL"
  end
end
