# frozen_string_literal: true

class IqdbConcurrencyResetJob < ApplicationJob
  queue_as :low_prio

  def perform
    keys = Cache.redis.scan_each(match: "iqdb:concurrent*").to_a
    Cache.redis.del(*keys) if keys.any?
  end
end
