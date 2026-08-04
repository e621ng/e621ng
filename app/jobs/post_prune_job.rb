# frozen_string_literal: true

# Deletes pending posts that were not approved within the moderation window.
# Not idempotent: each deleted post dmails its uploader, so a retry would
# send duplicate notifications.
class PostPruneJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options retry: false, lock: :until_executed

  def perform
    PostPruner.new.prune!
  end
end
