class StatsController < ApplicationController
  respond_to :html

  def index
    client = ::Redis.new(url: Danbooru.config.redis_url)
    @stats = JSON.parse(client.get('e6stats') || '{}')
    client.close
  end
end
