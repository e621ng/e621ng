# frozen_string_literal: true

class SearchTrendHourliesController < ApplicationController
  respond_to :html, :json
  before_action :admin_only

  def index
    @start_time = if params[:start_time].present?
                    begin
                      Time.parse(params[:start_time])
                    rescue StandardError
                      48.hours.ago
                    end
                  else
                    48.hours.ago
                  end

    @end_time = if params[:end_time].present?
                  begin
                    Time.parse(params[:end_time])
                  rescue StandardError
                    Time.current
                  end
                else
                  Time.current
                end

    @hourlies = SearchTrendHourly.where(hour: @start_time..@end_time)
                                 .search(hourly_params)
                                 .order(hour: :desc, count: :desc)
                                 .paginate(params[:page], limit: params[:limit])

    @count_offset = (@hourlies.current_page - 1) * @hourlies.records_per_page

    respond_to do |format|
      format.html
      format.json { render json: @hourlies.as_json(only: %i[tag count hour processed]) }
    end
  end

  private

  def hourly_params
    permitted_params = %i[start_time end_time name_matches]
    params.fetch(:search_trend_hourlies, {}).permit(permitted_params)
  end
end
