# frozen_string_literal: true

class SearchTrendHourliesController < ApplicationController
  respond_to :html, :json
  before_action :admin_only

  def index
    @hour = if params[:hour].present?
              begin
                Time.parse(params[:hour]).utc.beginning_of_hour
              rescue StandardError
                Time.now.utc.beginning_of_hour
              end
            else
              Time.now.utc.beginning_of_hour
            end

    @has_next_hour = @hour < Time.now.utc.beginning_of_hour

    @hourlies = SearchTrendHourly.for_hour(@hour)
                                 .search(hourly_params)
                                 .paginate(params[:page], limit: params[:limit])

    @count_offset = (@hourlies.current_page - 1) * @hourlies.records_per_page

    respond_to do |format|
      format.html
      format.json { render json: @hourlies.as_json(only: %i[tag count hour processed]) }
    end
  end

  private

  def hourly_params
    permitted_params = %i[name_matches]
    params.fetch(:search, {}).permit(permitted_params)
  end
end
