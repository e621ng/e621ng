# frozen_string_literal: true

class RelatedTagsController < ApplicationController
  # Budget in looked-up tags, not requests: one bulk request can cost 25.
  TAGS_PER_MINUTE = 300

  respond_to :json, :html, only: [:show]
  respond_to :json, only: [:bulk]
  before_action :member_only

  def show
    @related_tags = RelatedTagQuery.new(query: params[:search][:query], category_id: params[:search][:category_id])
    check_throttle(1)
    expires_in 30.seconds
    respond_with(@related_tags) do |format|
      format.json do
        render json: @related_tags.to_json
      end
    end
  end

  def bulk
    @related_tags = BulkRelatedTagQuery.new(query: params[:query], category_id: params[:category_id])
    check_throttle(@related_tags.query.size)
    respond_with(@related_tags) do |fmt|
      fmt.json do
        render json: @related_tags.to_json
      end
    end
  end

  private

  # GETs skip api_check, and its per-request bucket ignores the bulk fan-out anyway.
  def check_throttle(cost)
    raise APIThrottled if RateLimiter.throttle!("related_tags:#{CurrentUser.id}", limit: TAGS_PER_MINUTE, period: 1.minute, amount: [cost, 1].max)
  end
end
