# frozen_string_literal: true

class PoolVersionsController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def index
    if (pool_id = params.dig(:search, :pool_id)).present?
      @pool = Pool.find_by(id: pool_id)
    end

    @pool_versions = PoolVersion.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@pool_versions)
  end

  def diff
    @pool_version = PoolVersion.find(params[:id])
  end

  private

  def search_params
    permitted_params = %i[updater_id updater_name pool_id]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
