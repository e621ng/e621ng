module DangerZone
  def self.uploads_disabled?(user)
    user.level < min_upload_level
  end

  def self.min_upload_level
    (redis_client.get("min_upload_level") || User::Levels::MEMBER).to_i
  end

  def self.min_upload_level=(min_upload_level)
    redis_client.set("min_upload_level", min_upload_level)
  end

  def self.redis_client
    @@redis_client ||= ::Redis.new(url: Danbooru.config.redis_url)
  end
end
