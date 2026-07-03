# frozen_string_literal: true

Rails.application.config.after_initialize do
  Cache.redis.del(IqdbProxy.redis_key)
rescue Redis::BaseError => e
  Rails.logger.warn("Could not reset IQDB concurrency counter on startup: #{e.message}")
end
