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

  def create
    @blacklist = SearchTrendBlacklist.create(blacklist_params)
    respond_with(@blacklist, location: search_trend_blacklists_path)
  end

  def destroy
    @blacklist = SearchTrendBlacklist.find(params[:id])
    @blacklist.destroy
    respond_with(@blacklist)
  end

  def purge
    @blacklist = SearchTrendBlacklist.find(params[:id])
    deleted = @blacklist.purge!
    respond_to do |format|
      format.html { redirect_to search_trend_blacklists_path, notice: "Purged #{deleted} trend record(s) for \"#{@blacklist.tag}\"." }
      format.json { render json: { deleted_count: deleted } }
    end
  end

  private

  def search_params
    permit_search_params %i[order tag reason]
  end

  def blacklist_params
    params.require(:search_trend_blacklist).permit(%i[tag reason])
  end
end
