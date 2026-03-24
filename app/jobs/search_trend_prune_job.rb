# frozen_string_literal: true

class SearchTrendPruneJob < ApplicationJob
  queue_as :low_prio

  def perform
    SearchTrend.coalesce_hourly!
    SearchTrend.prune!
  end
end
