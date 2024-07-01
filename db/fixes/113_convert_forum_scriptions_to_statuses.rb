#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

ForumSubscription.find_each do |subscription|
  ForumTopicStatus.create(
    created_at: subscription.created_at,
    updated_at: subscription.updated_at,
    forum_topic_id: subscription.forum_topic_id,
    user_id: subscription.user_id,
    subscription_last_read_at: subscription.last_read_at,
    subscription: true,
  )
end
