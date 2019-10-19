require 'sidekiq'

Sidekiq.configure_server do |config|
  config.redis = { url: Danbooru.config.redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: Danbooru.config.redis_url }
end
