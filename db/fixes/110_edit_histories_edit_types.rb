#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# blips don't store an updater id
blip_updater = User.find(1)
# blips & fourm posts don't store an updater ip
ip_addr = "127.0.0.1"

# the default is original, so we need to update everything that isn't version=1
EditHistory.where.not(version: 1).find_each do |edit_history|
  edit_history.update_columns(edit_type: "edit")
end

Blip.where("is_hidden = TRUE OR warning_type IS NOT NULL").find_each do |blip|
  # blips have no updater information, so we're pretty well forced to leave everything anonymous
  CurrentUser.scoped(blip_updater, ip_addr) do
    blip.save_version("hide") if blip.is_hidden?
    blip.save_version("mark_#{blip.warning_type}") if blip.was_warned?
  end
end

Comment.where("is_hidden = TRUE OR is_sticky = TRUE OR warning_type IS NOT NULL").find_each do |comment|
  updater = User.find(comment.updater_id)
  CurrentUser.scoped(updater, comment.updater_ip_addr) do
    comment.save_version("hide") if comment.is_hidden?
    comment.save_version("stick") if comment.is_sticky?
    comment.save_version("mark_#{comment.warning_type}") if comment.was_warned?
  end

  # warning_user_id has never been set - we're updating it with the current updater_id, as that's likely to be the one who added the warning
  if comment.was_warned? && comment.warning_user_id.nil?
    comment.update_columns(warning_user_id: comment.updater_id)
  end
end

ForumPost.where("is_hidden = TRUE OR warning_type IS NOT NULL").find_each do |forum_post|
  updater = User.find(forum_post.updater_id)
  CurrentUser.scoped(updater, ip_addr) do
    forum_post.save_version("hide") if forum_post.is_hidden?
    forum_post.save_version("mark_#{forum_post.warning_type}") if forum_post.was_warned?
  end

  # warning_user_id has never been set - we're updating it with the current updater_id, as that's likely to be the one who added the warning
  if forum_post.was_warned? && forum_post.warning_user_id.nil?
    forum_post.update_columns(warning_user_id: forum_post.updater_id)
  end
end
