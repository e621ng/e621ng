# frozen_string_literal: true

class PoolsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index show gallery]
  before_action :janitor_only, only: %i[destroy]
  before_action :ensure_lockdown_disabled, except: %i[index show gallery]

  def new
    @pool = Pool.new
    respond_with(@pool)
  end

  def edit
    @pool = Pool.find(params[:id])
    respond_with(@pool)
  end

  def index
    @pools = Pool.search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@pools) do |format|
      format.json do
        render json: @pools.to_json
        expires_in params[:expiry].to_i.days if params[:expiry]
      end
    end
  end

  def gallery
    @pools = Pool.search(search_params).paginate_posts(params[:page], limit: params[:limit], search_count: params[:search])
  end

  def show
    @pool = Pool.find(params[:id])
    respond_with(@pool) do |format|
      format.html do
        @posts = @pool.posts.paginate_posts(params[:page], limit: params[:limit], total_count: @pool.post_ids.count)
      end
    end
  end

  def create
    @pool = Pool.create(pool_params)
    flash[:notice] = @pool.valid? ? "Pool created" : @pool.errors.full_messages.join("; ")
    respond_with(@pool)
  end

  def update
    # need to do this in order for synchronize! to work correctly
    @pool = Pool.find(params[:id])
    @pool.attributes = pool_params
    @pool.save
    unless @pool.errors.any?
      flash[:notice] = "Pool updated"
    end
    respond_with(@pool)
  end

  def destroy
    @pool = Pool.find(params[:id])
    if !@pool.deletable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
    @pool.create_mod_action_for_delete
    @pool.destroy
    flash[:notice] = "Pool deleted"
    respond_with(@pool)
  end

  def revert
    @pool = Pool.find(params[:id])
    @version = @pool.versions.find(params[:version_id])
    @pool.revert_to!(@version)
    flash[:notice] = "Pool reverted"
    respond_with(@pool) do |format|
      format.js
    end
  end

  private

  def pool_params
    permitted_params = %i[name description category is_active post_ids post_ids_string]
    params.require(:pool).permit(*permitted_params, post_ids: [])
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.pools_disabled? && !CurrentUser.is_staff?
  end
end
