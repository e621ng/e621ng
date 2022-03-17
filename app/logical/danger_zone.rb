module DangerZone
  def self.uploads_disabled?
    redis_client.get("disable_uploads") == "y"
  end

  def self.disable_uploads
    redis_client.set("disable_uploads", "y")
  end

  def self.enable_uploads
    redis_client.set("disable_uploads", "n")
  end

  def self.redis_client
    @@redis_client ||= ::Redis.new(url: Danbooru.config.redis_url)
  end
end
