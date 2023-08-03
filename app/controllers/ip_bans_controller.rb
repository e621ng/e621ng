class IpBansController < ApplicationController
  respond_to :html, :json
  before_action :admin_only

  def new
    @ip_ban = IpBan.new
  end

  def create
    @ip_ban = IpBan.create(ip_ban_params)
    respond_with(@ip_ban, location: ip_bans_path)
  end

  def index
    @ip_bans = IpBan.includes(:creator).search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@ip_bans)
  end

  def destroy
    @ip_ban = IpBan.find(params[:id])
    @ip_ban.destroy
    respond_with(@ip_ban)
  end

  private

  def ip_ban_params
    params.fetch(:ip_ban, {}).permit(%i[ip_addr reason])
  end

  def search_params
    permit_search_params %i[ip_addr banner_id banner_name reason]
  end
end
