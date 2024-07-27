# frozen_string_literal: true

class UserThrottle
  def initialize(options, user)
    @prefix = options[:prefix] || "thtl:"
    @duration = options[:duration] || 1.minute
    @user_id = user.id
    @max_rate = options[:max] || user.api_burst_limit

    @cached_rate = 0
  end

  def accept?
    (@max_rate - current_rate) > 0
  end

  def cached_count
    @max_rate - @cached_rate
  end

  def uncached_count
    @max_rate - current_rate
  end

  def throttled?
    if accept?
      hit!
      false
    else
      true
    end
  end

  private

  def cache_duration
    (@duration / 60.seconds).to_i + 1
  end

  def current_rate
    t = Time.now
    ckey = current_key(t)
    pkey = previous_key(t)
    tdiff = t.to_i - ctime(t)*@duration.to_i
    hits = Cache.redis.mget(ckey, pkey)
    @cached_rate = (hits[1].to_f * ((@duration.to_i-tdiff)/@duration.to_f) + hits[0].to_f).to_i
  end

  def hit!
    t = Time.now
    ckey = current_key(t)
    Cache.redis.multi do |transaction|
      transaction.incr(ckey)
      transaction.expire(ckey, cache_duration.minutes)
    end
  end

  def current_key(t)
    "#{throttle_prefix}#{ctime(t)}"
  end

  def previous_key(t)
    "#{throttle_prefix}#{ptime(t)}"
  end

  def ctime(t)
    ((t.to_i / @duration.to_i)).to_i
  end

  def ptime(t)
    ((t.to_i / @duration.to_i) - 1).to_i
  end

  def throttle_prefix
    "#{@prefix}#{@user_id}:"
  end
end
