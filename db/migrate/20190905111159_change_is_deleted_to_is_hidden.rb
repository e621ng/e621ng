class ChangeIsDeletedToIsHidden < ActiveRecord::Migration[6.0]
  def change
    rename_column :comments, :is_deleted, :is_hidden
    rename_column :forum_posts, :is_deleted, :is_hidden
    rename_column :forum_topics, :is_deleted, :is_hidden
  end
end
