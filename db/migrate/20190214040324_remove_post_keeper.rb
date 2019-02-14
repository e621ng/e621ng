class RemovePostKeeper < ActiveRecord::Migration[5.2]
  def up
    execute("set statement_timeout = 0")
    remove_column :posts, :keeper_data
  end
end
