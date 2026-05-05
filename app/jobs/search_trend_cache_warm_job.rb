# frozen_string_literal: true

class SearchTrendCacheWarmJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options lock: :until_executing

  def perform
    SearchTrendHourly.warm_rising_tags_cache!
  end
end
