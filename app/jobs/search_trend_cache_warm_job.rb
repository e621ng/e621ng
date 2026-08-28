# frozen_string_literal: true

class SearchTrendCacheWarmJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executing, lock_ttl: 12.hours.to_i

  def perform
    SearchTrendHourly.without_timeout do
      SearchTrendHourly.warm_rising_tags_cache!
    end
  end
end
