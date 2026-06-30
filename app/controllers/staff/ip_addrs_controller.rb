# frozen_string_literal: true

module Staff
  class IpAddrsController < ApplicationController
    before_action :admin_only
    respond_to :html, :json

    rescue_from Moderator::IpAddrSearch::InvalidIpAddr, with: :render_invalid_ip_addr

    def index
      search = Moderator::IpAddrSearch.new(params[:search] || {})
      @results = search.execute
      respond_with(@results)
    end

    def export
      unless params[:search].present? && (params[:search][:user_id].present? || params[:search][:user_name].present?)
        render json: [], status: 200
        return
      end

      search = Moderator::IpAddrSearch.new((params[:search] || {}).merge({ with_history: true }))
      @results = search.execute
      respond_with(@results) do |format|
        format.json do
          render json: @results[:ip_addrs].uniq
        end
      end
    end

    private

    def render_invalid_ip_addr(exception)
      render_expected_error(422, exception.message)
    end
  end
end
