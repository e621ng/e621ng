# frozen_string_literal: true

class StatsController < ApplicationController
  respond_to :html, :json

  def index
    @stats = JSON.parse(Cache.redis.get("e6stats") || "{}")
    respond_with(@stats)
  end
end
