#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

ApplicationRecord.without_timeout do
  CommentVote.left_joins(:comment).where("comments.id": nil).delete_all
  PostVote.left_joins(:post).where("posts.id": nil).delete_all
end
