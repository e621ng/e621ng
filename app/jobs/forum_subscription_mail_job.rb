# frozen_string_literal: true

# Sends forum topic digest emails to subscribed users. Not idempotent: a
# retry would resend the same digests.
class ForumSubscriptionMailJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options retry: false, lock: :until_executed

  def perform
    ForumSubscription.process_all!
  end
end
