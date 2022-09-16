class StatsController < ApplicationController
  respond_to :html

  def index
    client = RedisClient.client
    @stats = JSON.parse(client.get('e6stats') || '{}')
  end
end
