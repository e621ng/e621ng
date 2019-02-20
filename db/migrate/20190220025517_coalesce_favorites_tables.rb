class CoalesceFavoritesTables < ActiveRecord::Migration[5.2]
  def up
    create_table :temp_faves do |t|
      t.integer :user_id, type: "integer"
      t.integer :post_id, type: "integer"
    end

    # Remove the trigger and insert function
    execute <<~SQL
      DROP FUNCTION favorites_insert_trigger CASCADE;
    SQL

    # Copy data from all the descendant tables
    execute <<~SQL
      INSERT INTO temp_faves (user_id, post_id)
      SELECT user_id, post_id FROM favorites;
    SQL

    # Add indexes and constraints after all the importing
    # is done
    add_index :temp_faves, :user_id
    add_index :temp_faves, :post_id

    change_column_null :temp_faves, :user_id, false
    change_column_null :temp_faves, :post_id, false

    add_foreign_key :temp_faves, :users
    add_foreign_key :temp_faves, :posts

    # Remove all the descendant tables
    (0..99).each do |i|
      drop_table "favorites_#{i}"
    end

    # Then remove the original and rename in place
    drop_table :favorites
    rename_table :temp_faves, :favorites
  end

  def down
    fail ActiveRecord::IrreversibleMigration
  end
end
