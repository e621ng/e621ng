# frozen_string_literal: true

module DangerZone
  def self.uploads_disabled?(user)
    user.level < min_upload_level
  end

  def self.min_upload_level
    (Cache.redis.get("min_upload_level") || User::Levels::MEMBER).to_i
  rescue Redis::CannotConnectError
    User::Levels::ADMIN + 1
  end

  def self.min_upload_level=(min_upload_level)
    Cache.redis.set("min_upload_level", min_upload_level)
  end
end
