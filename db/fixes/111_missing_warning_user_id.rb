#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

# warning_user_id has never been set - we're updating it with the current updater_id, as they are very likely to be the one that added the warning
Comment.where("warning_type IS NOT NULL").find_each do |comment|
  if comment.was_warned? && comment.warning_user_id.nil?
    comment.update_columns(warning_user_id: comment.updater_id)
  end
end

ForumPost.where("warning_type IS NOT NULL").find_each do |forum_post|
  if forum_post.was_warned? && forum_post.warning_user_id.nil?
    forum_post.update_columns(warning_user_id: forum_post.updater_id)
  end
end
