# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :member_only
  before_action :reject_api_key_auth
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

  def create
    params = api_key_params.merge(user: CurrentUser.user)

    if params[:duration] == "never"
      params[:expires_at] = nil
    elsif params[:duration] != "custom" && params[:duration].present?
      days = params[:duration].to_i
      params[:expires_at] = days.days.from_now
    end

    params.delete(:duration)

    @api_key = ApiKey.create(params)

    if @api_key.errors.any?
      respond_with(@api_key)
    else
      flash[:notice] = "API key created"
      respond_with(@api_key, location: api_keys_path)
    end
  end

  def destroy
    @api_key.destroy
    flash[:notice] = "API key deleted"
    respond_with(@api_key, location: api_keys_path)
  end

  def regenerate
    unless @api_key.expired?
      render_expected_error(:unprocessable_entity, "Only expired API keys can be regenerated")
      return
    end

    @api_key.regenerate!
    flash[:notice] = "API key regenerated"
    respond_with(@api_key, location: api_keys_path)
  end

  private

  def load_api_key
    @api_key = CurrentUser.user.api_keys.find(params[:id])
  end

  def api_key_params
    params.fetch(:api_key, {}).permit(:name, :expires_at, :duration)
  end

  def search_params
    permitted_params = %i[name_matches is_expired order]
    permit_search_params permitted_params
  end
end
