#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

renames = {
  # User actions
  "banned_user" => "user_ban",
  "unbanned_user" => "user_unban",

  # Comment actions
  "deleted_comment" => "comment_delete",
  "unhid_comment" => "comment_unhide",

  # Pool actions
  "deleted_pool" => "pool_delete",

  # Forum actions
  "edited_forum_post" => "forum_post_update",
  "hid_forum_post" => "forum_post_hide",
  "unhid_forum_post" => "forum_post_unhide",
  "locked_forum_post" => "forum_topic_lock",
  "unlocked_forum_post" => "forum_topic_unlock",
  "stickied_forum_post" => "forum_topic_stick",
  "unstickied_forum_post" => "forum_topic_unstick",

  # Tag alias actions
  "created_alias" => "tag_alias_create",
  "deleted_alias" => "tag_alias_delete",
  "approved_alias" => "tag_alias_approve",
  "edited_alias" => "tag_alias_update",

  # Tag implication actions
  "created_implication" => "tag_implication_create",
  "deleted_implication" => "tag_implication_delete",
  "approved_implication" => "tag_implication_approve",
  "edited_implication" => "tag_implication_update",

  # Wiki page actions
  "deleted_wiki_page" => "wiki_page_delete",
  "renamed_wiki_page" => "wiki_page_rename",
  "locked_wiki_page" => "wiki_page_lock",
  "unlocked_wiki_page" => "wiki_page_unlock",

  # Set actions
  "made_set_private" => "set_change_visibility",

  # Report reason actions
  "created_report_reason" => "report_reason_create",
  "edited_report_reason" => "report_reason_update",

  # Typo fixes
  "post_desroy" => "post_destroy",
  "edited_uplupload_whitelist_updateoad_whitelist" => "upload_whitelist_update",
}

renames.each do |old_action, new_action|
  count = ModAction.where(action: old_action).count
  next if count == 0

  ModAction.without_timeout do
    ModAction.where(action: old_action).update_all(action: new_action)
  end
  puts "Renamed #{count} '#{old_action}' -> '#{new_action}'"
end

puts "Done."
