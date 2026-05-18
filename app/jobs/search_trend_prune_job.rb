# frozen_string_literal: true

class SearchTrendPruneJob < ApplicationJob
  queue_as :low_prio

  def perform
    SearchTrend.without_timeout do
      SearchTrendHourly.prune!
      SearchTrend.prune!
    end
  end
end
