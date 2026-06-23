# frozen_string_literal: true

class IqdbConcurrencyResetJob < ApplicationJob
  queue_as :low_prio

  def perform
    keys = Cache.redis.smembers("iqdb:concurrent:keys")
    return if keys.blank?
    Cache.redis.del(*keys)
    Cache.redis.del("iqdb:concurrent:keys")
  end
end
