class RedisClient
  def self.client
    @@_client ||= ::Redis.new(url: Danbooru.config.redis_url)
  end
end
