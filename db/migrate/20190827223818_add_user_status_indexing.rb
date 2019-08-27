class AddUserStatusIndexing < ActiveRecord::Migration[5.2]
  def up
    remove_index :user_statuses, :user_id
    add_index :user_statuses, :user_id, unique: true
  end

  def down
    remove_index :user_statuses, :user_id
    add_index :user_statuses, :user_id
  end
end
