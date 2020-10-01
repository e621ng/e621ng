# Rails.application.configure do
#   if Rails.env.test? || Danbooru.
#     cache_config = [:memory_store, { size: 32.megabytes }]
#   else
#     cache_config = [
#         :redis_cache_store,
#         {
#             url: Danbooru.config.redis_url,
#             namespace: Danbooru.config.safe_app_name,
#             connect_timeout:   30, # default: 20 seconds
#             write_timeout:    0.2, # default: 1 second
#             read_timeout:     0.2, # default: 1 second
#             reconnect_attempts: 0, # default: 0
#             error_handler: ->(method:, returning:, exception:) {
#               DanbooruLogger.log(exception, method: method, returning: returning)
#             }
#         }
#     ]
#   end
#
#   cache_store = ActiveSupport::Cache.lookup_store(cache_config)
#
#   config.cache_store = cache_store
#   config.action_controller.cache_store = cache_store
#   Rails.cache = cache_store
# end


Rails.application.configure do
  begin
    if Rails.env.test?
      config.cache_store = :memory_store, { size: 32.megabytes }
      config.action_controller.cache_store = :memory_store, { size: 32.megabytes }
      Rails.cache = ActiveSupport::Cache.lookup_store(Rails.application.config.cache_store)
    else
      config.cache_store = :mem_cache_store, Danbooru.config.memcached_servers, { namespace: Danbooru.config.safe_app_name }
      config.action_controller.cache_store = :mem_cache_store, Danbooru.config.memcached_servers, { namespace: Danbooru.config.safe_app_name }
      Rails.cache = ActiveSupport::Cache.lookup_store(Rails.application.config.cache_store)
    end
  end
end
