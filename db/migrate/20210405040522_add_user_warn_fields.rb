class AddUserWarnFields < ActiveRecord::Migration[6.1]
  def change
    add_column :blips, :warning_type, :integer
    add_column :blips, :warning_user_id, :integer
    add_column :forum_posts, :warning_type, :integer
    add_column :forum_posts, :warning_user_id, :integer
    add_column :comments, :warning_type, :integer
    add_column :comments, :warning_user_id, :integer
  end
end
