# frozen_string_literal: true

class RenameHideToDelete < ActiveRecord::Migration[7.1]
  def up
    rename_column :comments, :is_hidden, :is_deleted
    rename_column :users, :show_hidden_comments, :show_deleted_comments
    rename_column :forum_posts, :is_hidden, :is_deleted
    rename_column :forum_topics, :is_hidden, :is_deleted
    rename_column :blips, :is_hidden, :is_deleted
    rename_column :post_versions, :is_hidden, :is_deleted

    execute("UPDATE mod_actions SET action = 'comment_destroy' WHERE action = 'comment_delete'")
    execute("UPDATE mod_actions SET action = 'comment_delete' WHERE action = 'comment_hide'")
    execute("UPDATE mod_actions SET action = 'comment_undelete' WHERE action = 'comment_unhide'")

    execute("UPDATE mod_actions SET action = 'forum_post_destroy' WHERE action = 'forum_post_delete'")
    execute("UPDATE mod_actions SET action = 'forum_post_delete' WHERE action = 'forum_post_hide'")
    execute("UPDATE mod_actions SET action = 'forum_post_undelete' WHERE action = 'forum_post_unhide'")

    execute("UPDATE mod_actions SET action = 'forum_topic_destroy' WHERE action = 'forum_topic_delete'")
    execute("UPDATE mod_actions SET action = 'forum_topic_delete' WHERE action = 'forum_topic_hide'")
    execute("UPDATE mod_actions SET action = 'forum_topic_undelete' WHERE action = 'forum_topic_unhide'")

    execute("UPDATE mod_actions SET action = 'blip_destroy' WHERE action = 'blip_delete'")
    execute("UPDATE mod_actions SET action = 'blip_delete' WHERE action = 'blip_hide'")
    execute("UPDATE mod_actions SET action = 'blip_undelete' WHERE action = 'blip_unhide'")

    execute("UPDATE mod_actions SET action = 'post_version_delete' WHERE action = 'post_version_hide'")
    execute("UPDATE mod_actions SET action = 'post_version_undelete' WHERE action = 'post_version_unhide'")
  end

  def down
    execute("UPDATE mod_actions SET action = 'comment_hide' WHERE action = 'comment_delete'")
    execute("UPDATE mod_actions SET action = 'comment_unhide' WHERE action = 'comment_undelete'")
    execute("UPDATE mod_actions SET action = 'comment_delete' WHERE action = 'comment_destroy'")

    execute("UPDATE mod_actions SET action = 'forum_post_hide' WHERE action = 'forum_post_delete'")
    execute("UPDATE mod_actions SET action = 'forum_post_unhide' WHERE action = 'forum_post_undelete'")
    execute("UPDATE mod_actions SET action = 'forum_post_delete' WHERE action = 'forum_post_destroy'")

    execute("UPDATE mod_actions SET action = 'forum_topic_hide' WHERE action = 'forum_topic_delete'")
    execute("UPDATE mod_actions SET action = 'forum_topic_unhide' WHERE action = 'forum_topic_undelete'")
    execute("UPDATE mod_actions SET action = 'forum_topic_delete' WHERE action = 'forum_topic_destroy'")

    execute("UPDATE mod_actions SET action = 'blip_hide' WHERE action = 'blip_delete'")
    execute("UPDATE mod_actions SET action = 'blip_unhide' WHERE action = 'blip_undelete'")
    execute("UPDATE mod_actions SET action = 'blip_delete' WHERE action = 'blip_destroy'")

    execute("UPDATE mod_actions SET action = 'post_version_hide' WHERE action = 'post_version_delete'")
    execute("UPDATE mod_actions SET action = 'post_version_unhide' WHERE action = 'post_version_undelete'")

    rename_column :comments, :is_deleted, :is_hidden
    rename_column :users, :show_deleted_comments, :show_hidden_comments
    rename_column :forum_posts, :is_deleted, :is_hidden
    rename_column :forum_topics, :is_deleted, :is_hidden
    rename_column :blips, :is_deleted, :is_hidden
    rename_column :post_versions, :is_deleted, :is_hidden
  end
end
