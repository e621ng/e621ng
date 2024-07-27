# frozen_string_literal: true

class RateLimiter
  def self.check_limit(key, max_attempts, lockout_time = 1.minute)
    return true if Cache.fetch("#{key}:lockout")

    attempts = Cache.fetch(key) || 0
    if attempts >= max_attempts
      Cache.write("#{key}:lockout", true, expires_in: lockout_time)
      reset_limit(key)
      return true
    end
    false
  end

  def self.hit(key, time_period = 1.minute)
    value = Cache.fetch(key) || 0
    Cache.write(key, value.to_i + 1, expires_in: time_period)
    value.to_i + 1
  end

  def self.reset_limit(key)
    Cache.delete(key)
  end
end
