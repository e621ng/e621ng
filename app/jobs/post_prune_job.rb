# frozen_string_literal: true

# Deletes pending posts that were not approved within the moderation window.
# Not idempotent: each deleted post dmails its uploader, so a retry would
# send duplicate notifications.
class PostPruneJob < ApplicationJob
  sidekiq_options queue: "low_prio", retry: false, lock: :until_executed, lock_ttl: 12.hours.to_i

  def perform
    PostPruner.new.prune!
  end
end
