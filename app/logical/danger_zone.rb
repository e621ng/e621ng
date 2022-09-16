module DangerZone
  def self.uploads_disabled?(user)
    user.level < min_upload_level
  end

  def self.min_upload_level
    (RedisClient.client.get("min_upload_level") || User::Levels::MEMBER).to_i
  end

  def self.min_upload_level=(min_upload_level)
    RedisClient.client.set("min_upload_level", min_upload_level)
  end
end
