# frozen_string_literal: true

class SearchTrendsController < ApplicationController
  respond_to :html, :json
  before_action :admin_only, only: %i[settings update_settings clear_cache]

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
      format.json { render json: @trending.as_json(only: %i[tag count day]) }
    end
  end

  def settings
  end

  def update_settings
    if params.key?(:trends_enabled)
      Setting.trends_enabled = ActiveModel::Type::Boolean.new.cast(params[:trends_enabled])
    end
    if params[:trends_min_today].present?
      Setting.trends_min_today = params[:trends_min_today].to_i
    end
    if params[:trends_min_delta].present?
      Setting.trends_min_delta = params[:trends_min_delta].to_i
    end
    if params[:trends_min_ratio].present?
      Setting.trends_min_ratio = params[:trends_min_ratio].to_f
    end
    if params[:trends_ip_limit].present?
      Setting.trends_ip_limit = params[:trends_ip_limit].to_i
    end
    if params[:trends_ip_window].present?
      Setting.trends_ip_window = params[:trends_ip_window].to_i
    end
    if params[:trends_tag_limit].present?
      Setting.trends_tag_limit = params[:trends_tag_limit].to_i
    end
    if params[:trends_tag_window].present?
      Setting.trends_tag_window = params[:trends_tag_window].to_i
    end

    Cache.delete("rising_tags")

    respond_to do |format|
      format.html { redirect_to search_trends_path, notice: "Trend settings updated and cache cleared" }
      format.json { render json: { success: true, message: "Trend settings updated and cache cleared" } }
    end
  end

  def clear_cache
    Cache.delete("rising_tags")
    respond_to do |format|
      format.html { redirect_to search_trends_path, notice: "Rising tags cache cleared" }
      format.json { render json: { success: true, message: "Rising tags cache cleared" } }
    end
  end
end
