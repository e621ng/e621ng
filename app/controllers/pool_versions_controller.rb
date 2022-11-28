class PoolVersionsController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def index
    if params[:search] && params[:search][:pool_id].present?
      @pool = Pool.find(params[:search][:pool_id])
    end

    @pool_versions = PoolVersion.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@pool_versions)
  end

  def diff
    @pool_version = PoolVersion.find(params[:id])

    if params[:other_id]
      @other_version = PoolVersion.find(params[:other_id])
    else
      @other_version = @pool_version.previous
    end
  end

  private

  def search_params
    permitted_params = %i[updater_id updater_name pool_id]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
