# frozen_string_literal: true

class SearchTrendsController < ApplicationController
  respond_to :html, :json

  def index
    if params[:day].present?
      @day = begin
        Date.parse(params[:day])
      rescue StandardError
        Date.current
      end
    else
      @day = Date.current
    end
    @trending = SearchTrend.top_for_day(day: @day, limit: params[:limit] || 100)

    respond_to do |format|
      format.html
      format.json { render json: @trending.as_json(only: [:tag, :count, :day]) }
    end
  end
end
