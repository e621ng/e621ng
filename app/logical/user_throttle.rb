class UserThrottle
  def initialize(options, user)
    @prefix = options[:prefix] || "thtl:"
    @duration = options[:duration] || 1.minute
    @user_id = user.id
    @token_count = user.api_burst_limit
    @regen_rate = user.api_regen_multiplier

    @current_tokens = 0
  end

  def accept?
    @current_tokens >= 1
  end

  def cached_count
    @current_tokens
  end

  def uncached_count
    current = retrieve
    current[:tokens]
  end

  def throttled?
    add!

    if accept?
      consume!
      false
    else
      true
    end
  end

  private

  def cache_duration
    (@duration / 60.seconds).to_i + 1
  end

  def add!
    now = Time.now

    current = retrieve
    tokens = current[:tokens]
    tokens += ((now - current[:touched]) / @duration) * @regen_rate
    tokens = tokens.to_i
    tokens = @token_count if tokens > @token_count
    redis_client.multi do
      redis_client.hset(throttle_key, "t", tokens)
      redis_client.expire(throttle_key, cache_duration.minutes)
    end
    @current_tokens = tokens
  end

  def consume!
    @current_tokens = redis_client.multi do
      redis_client.hincrby(throttle_key, "t", -1)
      redis_client.hset(throttle_key, "e", Time.now.to_i)
      redis_client.expire(throttle_key, cache_duration.minutes)
    end
    @current_tokens = @current_tokens[0].to_i
  end

  def retrieve
    val = redis_client.hmget(throttle_key, "t", "e")
    if val[0].nil? || val[1].nil?
      return {tokens: @token_count, touched: Time.now}
    end
    tokens = val[0].to_i
    tokens = 0 if tokens < 0
    {tokens: tokens, touched: Time.at(val[1].to_i)}
  end

  def throttle_key
    "#{@prefix}#{@user_id}"
  end

  def redis_client
    @@client ||= ::Redis.new(url: Danbooru.config.redis_url)
  end
end