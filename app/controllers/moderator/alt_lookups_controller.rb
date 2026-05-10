# frozen_string_literal: true

module Moderator
  class AltLookupsController < ApplicationController
    before_action :moderator_only
    before_action :check_alt_lookup_rate_limit, only: %i[index]
    respond_to :html

    def new
    end

    def index
      unless Moderator::AltDetection.enabled?
        return render_expected_error(503, "Alt detection is currently disabled")
      end

      @target = User.find_by_name_or_id(params[:user_name].to_s.strip)
      unless @target
        return render_expected_error(404, "User not found")
      end

      @results = Moderator::AltLookup.new(@target).execute
      @users = User.where(id: @results.map { |r| r[:user_id] }).index_by(&:id)
    end

    private

    def check_alt_lookup_rate_limit
      key = "alt_lookup.#{CurrentUser.id}"
      max = Moderator::AltDetection.lookups_per_minute
      if RateLimiter.check_limit(key, max, 1.minute)
        render_expected_error(429, "You are running alt lookups too quickly. Wait a bit and try again.")
      else
        RateLimiter.hit(key, 1.minute)
      end
    end
  end
end
