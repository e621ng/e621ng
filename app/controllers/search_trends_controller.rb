# frozen_string_literal: true

class SearchTrendsController < ApplicationController
  respond_to :html, :json
  before_action :admin_only, only: %i[destroy settings update_settings clear_cache]

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
    @trending = SearchTrend.for_day_totals(@day).paginate(params[:page], limit: params[:limit])
    @count_offset = (@trending.current_page - 1) * @trending.records_per_page

    respond_to do |format|
      format.html
      format.json { render json: @trending.as_json(only: %i[tag count day]) }
    end
  end

  def show
    @tag = params[:id]
    @trends = SearchTrend.for_tag(@tag).limit(100).order(day: :desc, hour: :desc)
    respond_to do |format|
      format.html
      format.json { render json: @trends.as_json(only: %i[tag count day hour]) }
    end
  end

  def destroy
    @tag = params[:id]
    deleted = SearchTrend.for_tag(@tag).delete_all
    respond_to do |format|
      format.html { redirect_to search_trends_path, notice: "Purged #{deleted} trend record(s) for \"#{@tag}\"" }
      format.json { render json: { deleted_count: deleted } }
    end
  end

  def rising
    respond_to do |format|
      format.html
      format.json { render json: SearchTrend.rising_tags_list.as_json(only: %i[tag]) }
    end
  end

  def settings
  end

  def update_settings
    params = trends_params

    if params.key?(:trends_enabled)
      Setting.trends_enabled = ActiveModel::Type::Boolean.new.cast(params[:trends_enabled])
    end
    if params.key?(:trends_displayed)
      Setting.trends_displayed = ActiveModel::Type::Boolean.new.cast(params[:trends_displayed])
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

  def trends_params
    permitted_params = %i[trends_enabled trends_displayed trends_min_today trends_min_delta trends_min_ratio trends_ip_limit trends_ip_window trends_tag_limit trends_tag_window]
    params.fetch(:search_trends, {}).permit(permitted_params)
  end
end
