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

  # Count-then-check in one atomic step, for sites where every attempt counts.
  # Admission is decided from the increment's own returned count, not a separate
  # read: a request is allowed only if the window was still under the limit
  # *before* this attempt. That closes the concurrent stale-read overshoot — two
  # callers can no longer both read an under-limit count and both be admitted —
  # but it is NOT a strict unit cap. It preserves the prior semantics, where an
  # attempt that finds any remaining budget is admitted in full, so a weighted
  # attempt can still carry the running total past +limit+ by up to amount-1
  # (e.g. two amount:6 attempts under limit:10 both pass, reaching 12). Returns
  # true if the caller should reject the request. +amount+ weights attempts that
  # cost more. A rejected attempt still counts (the increment is what makes the
  # decision atomic); the window is unchanged and still expires +period+ after
  # the first hit.
  def self.throttle!(key, limit:, period:, lockout: nil, amount: 1)
    limiter = new(key, limit: limit, period: period, lockout: lockout)
    return true if limiter.locked_out?
    # hit! returns the post-increment count; count - amount is this attempt's
    # pre-count, so admission can't be fooled by a stale concurrent read.
    limiter.hit!(amount) - amount >= limit
  end

  def initialize(key, limit:, period:, lockout: nil)
    @key = "throttle:#{key}"
    @limit = limit
    @period = period
    @lockout = lockout
  end

  # Read-only: never increments, never trips or extends a lockout.
  def throttled?
    return true if locked_out?
    Cache.fetch(@key, raw: true).to_i >= limit
  end

  # Read-only: true while a tripped lockout is still in effect.
  def locked_out?
    lockout.present? && Cache.fetch(lockout_key).present?
  end

  # Returns the count within the current window. Exactly one concurrent hit
  # crosses the limit, so the lockout is written once per window.
  def hit!(amount = 1)
    count = Cache.increment(@key, amount, expires_in: period).to_i
    Cache.write(lockout_key, true, expires_in: lockout) if lockout && count >= limit && count - amount < limit
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
