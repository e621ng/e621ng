# frozen_string_literal: true

class SearchTrendsController < ApplicationController
  respond_to :html, :json
  before_action :admin_only, only: %i[purge settings update_settings clear_cache]

  def index
    if params[:day].present?
      @day = begin
        Date.parse(params[:day])
      rescue StandardError
        Time.now.utc.to_date
      end
    else
      @day = Time.now.utc.to_date
    end

    search_filters_present = search_params[:name_matches].present?

    if search_filters_present
      @trending = SearchTrend.for_day_ranked(@day).search(search_params).paginate(params[:page], limit: params[:limit])
      @using_calculated_ranks = true
    else
      @trending = SearchTrend.for_day(@day).search(search_params).paginate(params[:page], limit: params[:limit])
      @using_calculated_ranks = false
    end

    @has_tomorrow = @day < Time.now.utc.to_date
    @count_offset = (@trending.current_page - 1) * @trending.records_per_page

    respond_to do |format|
      format.html
      format.json { render json: @trending.as_json(only: %i[tag count day]) }
    end
  end

  def track
    @tags = params[:tag].to_s.downcase.strip.split(",").uniq.first(10)

    respond_to do |format|
      format.html do
        @hourlies = SearchTrendHourly.where(tag: @tags).order(hour: :desc).limit(50)
      end
      format.json do
        @trends = SearchTrend.for_graph(@tags)
        render json: @trends.transform_values { |rows| rows.as_json(only: %i[count day]) }
      end
    end
  end

  def purge
    @tag = params[:tag].to_s.downcase.strip
    deleted_daily = SearchTrend.for_tag(@tag).delete_all
    deleted_hourly = SearchTrendHourly.where(tag: @tag).delete_all
    respond_to do |format|
      format.html { redirect_to search_trends_path, notice: "Purged #{deleted_daily} historic record(s) and #{deleted_hourly} hourly record(s) for \"#{@tag}\"" }
      format.json { render json: { daily_count: deleted_daily, hourly_count: deleted_hourly } }
    end
  end

  def rising
    respond_to do |format|
      format.html
      format.json { render json: SearchTrendHourly.rising_tags_list.as_json }
    end
  end

  def settings
  end

  def update_settings
    params = trend_settings_params

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

  def search_params
    permitted_params = %i[name_matches]
    permit_search_params permitted_params
  end

  def trend_settings_params
    permitted_params = %i[trends_enabled trends_displayed trends_min_today trends_min_delta trends_min_ratio trends_ip_limit trends_ip_window trends_tag_limit trends_tag_window]
    params.fetch(:search_trend_settings, {}).permit(permitted_params)
  end
end
