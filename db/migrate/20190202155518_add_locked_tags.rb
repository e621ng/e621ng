class AddLockedTags < ActiveRecord::Migration[5.2]
  def change
    execute "set statement_timeout = 0"
    add_column :posts, :locked_tags, :text, :null => true
  end
end
