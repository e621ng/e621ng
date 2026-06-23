# frozen_string_literal: true

class IqdbConcurrencyResetJob < ApplicationJob
  queue_as :low_prio

  def perform
    keys = Cache.redis.smembers("iqdb:concurrent:keys")
    Cache.redis.del(*keys) if keys.any?
    Cache.redis.del("iqdb:concurrent:keys")
  end
end
