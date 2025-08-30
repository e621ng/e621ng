# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :member_only
  before_action :requires_reauthentication
  before_action :load_api_key, except: %i[index new create]
  respond_to :html, :json

  def index
    @api_keys = ApiKey.visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@api_keys)
  end

  def new
    @api_key = ApiKey.new(user: CurrentUser.user)
    respond_with(@api_key)
  end

  def edit
    respond_with(@api_key)
  end

  def create
    @api_key = ApiKey.create(api_key_params.merge(user: CurrentUser.user))

    if @api_key.errors.any?
      respond_with(@api_key)
    else
      flash[:notice] = "API key created"
      respond_with(@api_key, location: api_keys_path)
    end
  end

  def update
    if @api_key.update(api_key_params)
      flash[:notice] = "API key updated"
      respond_with(@api_key, location: api_keys_path)
    else
      respond_with(@api_key)
    end
  end

  def destroy
    @api_key.destroy
    flash[:notice] = "API key deleted"
    respond_with(@api_key, location: api_keys_path)
  end

  private

  def load_api_key
    @api_key = CurrentUser.user.api_keys.find(params[:id])
  end

  def api_key_params
    params.fetch(:api_key, {}).permit(:name, :expires_at)
  end

  def search_params
    permitted_params = %i[name_matches user_name user_id is_expired order]
    permit_search_params permitted_params
  end
end
