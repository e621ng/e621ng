# frozen_string_literal: true

class ArtistVersionsController < ApplicationController
  respond_to :html, :json

  def index
    @artist_versions = ArtistVersion.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@artist_versions)
  end

  private

  def search_params
    permitted_params = %i[name updater_name updater_id artist_id is_active order]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
