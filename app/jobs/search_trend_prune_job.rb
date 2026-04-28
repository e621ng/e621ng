# frozen_string_literal: true

class SearchTrendPruneJob < ApplicationJob
  queue_as :low_prio

  def perform
    SearchTrendHourly.prune!
    SearchTrend.prune!
  end
end
