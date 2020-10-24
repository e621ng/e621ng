class RateLimiter
  def self.check_limit(key, max_attempts, lockout_time = 1.minute)
    return true if Cache.get("#{key}:lockout")

    attempts = Cache.get(key) || 0
    if attempts >= max_attempts
      Cache.put("#{key}:lockout", true, lockout_time)
      reset_limit(key)
      return true
    end
    false
  end

  def self.hit(key, time_period = 1.minute)
    value = Cache.get(key) || 0
    Cache.put(key, value.to_i + 1, time_period)
    return value.to_i + 1
  end

  def self.reset_limit(key)
    Cache.delete(key)
  end

end
