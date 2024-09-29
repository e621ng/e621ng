#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.without_timeout do
  Post.where(is_comment_disabled: true).update_all("is_comment_locked = is_comment_disabled, is_comment_disabled = false")
end
