# frozen_string_literal: true

class SearchTrendCacheWarmJob < ApplicationJob
  # Runs every 15 minutes; scope the lock_ttl to match that.
  sidekiq_options queue: "low_prio", lock: :until_executing, lock_ttl: 15.minutes.to_i

  def perform
    SearchTrendHourly.without_timeout do
      SearchTrendHourly.warm_rising_tags_cache!
    end
  end
end
