class RemovePostIsBanned < ActiveRecord::Migration[5.2]
  def up
    execute("set statement_timeout = 0")
    remove_column :posts, :is_banned
  end

  def down
    execute("set statement_timeout = 0")
    add_column :posts, :is_banned, :boolean, :null => false, :default => false
  end
end
