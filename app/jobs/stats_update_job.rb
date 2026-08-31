# frozen_string_literal: true

# Recalculates the site-wide statistics shown on /stats and caches them in
# Redis. Idempotent, but the aggregate queries are heavy.
class StatsUpdateJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executed, lock_ttl: 12.hours.to_i

  def perform
    ApplicationRecord.without_timeout do
      StatsUpdater.run!
    end
  end
end
