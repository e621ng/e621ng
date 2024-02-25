# frozen_string_literal: true

module Moderator
  class IpAddrsController < ApplicationController
    before_action :admin_only
    respond_to :html, :json

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
  end
end
