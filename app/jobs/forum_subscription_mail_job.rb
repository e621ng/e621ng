# frozen_string_literal: true

# Sends forum topic digest emails to subscribed users. Not idempotent: a
# retry would resend the same digests.
class ForumSubscriptionMailJob < ApplicationJob
  sidekiq_options queue: "low_prio", retry: false, lock: :until_executed, lock_ttl: 12.hours.to_i

  def perform
    ForumSubscription.process_all!
  end
end
