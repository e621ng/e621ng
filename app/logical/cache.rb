# frozen_string_literal: true

class Cache
  def self.read_multi(keys, prefix)
    sanitized_key_to_key_hash = keys.index_by { |key| "#{prefix}:#{key}" }

    sanitized_keys = sanitized_key_to_key_hash.keys
    sanitized_key_to_value_hash = Rails.cache.read_multi(*sanitized_keys)

    sanitized_key_to_value_hash.transform_keys(&sanitized_key_to_key_hash)
  end

  def self.fetch(key, expires_in: nil, &)
    Rails.cache.fetch(key, expires_in: expires_in, &)
  end

  def self.write(key, value, expires_in: nil)
    Rails.cache.write(key, value, expires_in: expires_in)
  end

  def self.delete(key)
    Rails.cache.delete(key)
  end

  def self.clear
    Rails.cache.clear
  end

  def self.redis
    # Using a shared variable like this here is OK
    # since pitchfork spawns a new process for each worker
    @redis ||= Redis.new(url: Danbooru.config.redis_url)
  end
end
