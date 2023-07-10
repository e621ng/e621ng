class StatsController < ApplicationController
  respond_to :html

  def index
    @stats = JSON.parse(Cache.redis.get("e6stats") || "{}")
  end
end
