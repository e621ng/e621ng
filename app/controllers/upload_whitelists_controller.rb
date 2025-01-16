# frozen_string_literal: true

class UploadWhitelistsController < ApplicationController
  respond_to :html, :json, :js
  before_action :admin_only, only: [:new, :create, :edit, :update, :destroy]
  before_action :load_whitelist, only: %i[edit update destroy]

  def index
    @whitelists = UploadWhitelist.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@whitelists)
  end

  def new
    @whitelist = UploadWhitelist.new
  end

  def edit
    respond_with(@whitelist)
  end

  def create
    @whitelist = UploadWhitelist.create(whitelist_params)
    respond_with(@whitelist, location: upload_whitelists_path)
  end

  def update
    @whitelist.update(whitelist_params)
    flash[:notice] = @whitelist.valid? ? "Entry updated" : @whitelist.errors.full_messages.join("; ")
    redirect_to(upload_whitelists_path)
  end

  def destroy
    @whitelist.destroy
    respond_with(@whitelist)
  end

  def is_allowed
    begin
      url_parsed = Addressable::URI.heuristic_parse(params[:url])
      allowed, reason = UploadWhitelist.is_whitelisted?(url_parsed)
      @whitelist = {
          url: params[:url],
          domain: url_parsed.domain,
          is_allowed: allowed,
          reason: reason
      }
    rescue Addressable::URI::InvalidURIError => e
      @whitelist = {
          url: params[:url],
          domain: 'invalid domain',
          is_allowed: false,
          reason: 'invalid domain'
      }
    end
    respond_with(@whitelist) do |format|
      format.json { render json: @whitelist }
    end
  end

  private

  def load_whitelist
    @whitelist = UploadWhitelist.find(params[:id])
  end

  def search_params
    permit_search_params %i[allowed order pattern note reason]
  end

  def whitelist_params
    params.require(:upload_whitelist).permit(%i[allowed pattern reason note hidden])
  end
end
