# frozen_string_literal: true

# Recalculates the site-wide statistics shown on /stats and caches them in
# Redis. Idempotent, but the aggregate queries are heavy.
class StatsUpdateJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options lock: :until_executed

  def perform
    ApplicationRecord.without_timeout do
      StatsUpdater.run!
    end
  end
end
