# frozen_string_literal: true

# Fixed-window rate limiter backed by atomic cache increments.
#
# The window starts at the first hit and expires +period+ later; hits inside
# the window do NOT extend it. "limit: 30, period: 1.minute" therefore means
# what it reads as: at most 30 hits per minute.
#
# Checking and counting are separate so call sites can decide what counts:
# every attempt (use RateLimiter.throttle!), only failures (login, TOTP), or
# only successes (email changes, invites).
#
#   limiter = RateLimiter.new("totp:#{user.id}", limit: 10, period: 1.hour, lockout: 1.hour)
#   return :rate_limited if limiter.throttled?
#   ...
#   limiter.hit! unless code_valid
#
# With lockout: nil, exceeding the limit blocks until the window expires.
# With a lockout duration, the hit that reaches the limit starts a lockout
# lasting that long, independent of the window.
class RateLimiter
  attr_reader :limit, :period, :lockout

  # Check-then-count in one call, for sites where every attempt counts.
  # Returns true if the caller should reject the request; otherwise records
  # the hit and returns false.
  def self.throttle!(key, limit:, period:, lockout: nil)
    limiter = new(key, limit: limit, period: period, lockout: lockout)
    return true if limiter.throttled?
    limiter.hit!
    false
  end

  def initialize(key, limit:, period:, lockout: nil)
    @key = "throttle:#{key}"
    @limit = limit
    @period = period
    @lockout = lockout
  end

  # Read-only: never increments, never trips or extends a lockout.
  def throttled?
    return true if lockout && Cache.fetch(lockout_key)
    Cache.fetch(@key, raw: true).to_i >= limit
  end

  # Returns the count within the current window. Exactly one concurrent hit
  # observes count == limit, so the lockout is written once per window.
  def hit!
    count = Cache.increment(@key, expires_in: period).to_i
    Cache.write(lockout_key, true, expires_in: lockout) if lockout && count == limit
    count
  end

  def reset!
    Cache.delete(@key)
    Cache.delete(lockout_key)
  end

  private

  def lockout_key
    "#{@key}:lockout"
  end
end
