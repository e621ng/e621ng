# frozen_string_literal: true

class RenameHideToDelete < ActiveRecord::Migration[7.1]
  def up
    rename_column :comments, :is_hidden, :is_deleted
    rename_column :users, :show_hidden_comments, :show_deleted_comments

    execute("UPDATE mod_actions SET action = 'comment_destroy' WHERE action = 'comment_delete'")
    execute("UPDATE mod_actions SET action = 'comment_delete' WHERE action = 'comment_hide'")
    execute("UPDATE mod_actions SET action = 'comment_undelete' WHERE action = 'comment_unhide'")
  end

  def down
    execute("UPDATE mod_actions SET action = 'comment_hide' WHERE action = 'comment_delete'")
    execute("UPDATE mod_actions SET action = 'comment_unhide' WHERE action = 'comment_undelete'")
    execute("UPDATE mod_actions SET action = 'comment_delete' WHERE action = 'comment_destroy'")

    rename_column :comments, :is_deleted, :is_hidden
    rename_column :users, :show_deleted_comments, :show_hidden_comments
  end
end
