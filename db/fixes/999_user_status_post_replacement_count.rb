#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

User.find_each do |user|
  UserStatus.for_user(user.id).update_all(post_replacement_submitted_count: PostReplacement.where(creator_id: user.id).where.not(status: "original").count)
end
