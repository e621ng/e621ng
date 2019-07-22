module TagChangeNoticeService
  extend self

  def redis_client
    ::Redis.new(url: Danbooru.config.redis_url)
  end

  def get_forum_topic_id(tag)
    false #redis_client.get("tcn:#{tag}")
  end

  def update_cache(affected_tags, forum_topic_id)
    # TODO: Revisit this idea and making it work with some kind of cache invalidation.
    # rc = redis_client
    # affected_tags.each do |tag|
    #   rc.setex("tcn:#{tag}", 1.week, forum_topic_id)
    # end
  end
end
