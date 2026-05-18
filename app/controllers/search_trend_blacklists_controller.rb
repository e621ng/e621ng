# frozen_string_literal: true

class SearchTrendBlacklistsController < ApplicationController
  respond_to :html, :json
  before_action :admin_only

  def index
    @blacklists = SearchTrendBlacklist.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@blacklists)
  end

  def new
    @blacklist = SearchTrendBlacklist.new
  end

  def edit
    @blacklist = SearchTrendBlacklist.find(params[:id])
  end

  def create
    @blacklist = SearchTrendBlacklist.create(blacklist_params)
    respond_with(@blacklist, location: search_trend_blacklists_path)
  end

  def update
    @blacklist = SearchTrendBlacklist.find(params[:id])
    @blacklist.update(blacklist_params)
    respond_with(@blacklist, location: search_trend_blacklists_path)
  end

  def destroy
    @blacklist = SearchTrendBlacklist.find(params[:id])
    @blacklist.destroy
    respond_with(@blacklist)
  end

  private

  def search_params
    permit_search_params %i[order tag reason]
  end

  def blacklist_params
    params.require(:search_trend_blacklist).permit(%i[tag reason])
  end
end
