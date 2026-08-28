# frozen_string_literal: true

class SearchTrendPruneJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def perform
    SearchTrend.without_timeout do
      SearchTrendHourly.prune!
      SearchTrend.prune!
    end
  end
end
