# frozen_string_literal: true

module Moderator
  class IpAddrsController < ApplicationController
    before_action :admin_only
    respond_to :html, :json

    rescue_from IpAddrSearch::InvalidIpAddr, with: :render_invalid_ip_addr

    def index
      search = IpAddrSearch.new(params[:search])
      @results = search.execute
      respond_with(@results)
    end

    def export
      search = IpAddrSearch.new(params[:search].merge({with_history: true}))
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
