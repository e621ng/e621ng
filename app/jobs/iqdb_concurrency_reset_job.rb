# frozen_string_literal: true

class IqdbConcurrencyResetJob < ApplicationJob
  sidekiq_options queue: "low_prio"

  def perform
    keys = Cache.redis.smembers("iqdb:concurrent:keys")
    return if keys.blank?
    Cache.redis.del(*keys)
    Cache.redis.del("iqdb:concurrent:keys")
  end
end
