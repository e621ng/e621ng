# frozen_string_literal: true

class AvoidPostingVersionsController < ApplicationController
  respond_to :html, :json

  def index
    @avoid_posting_versions = AvoidPostingVersion.includes(:avoid_posting, :artist, :updater).search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@avoid_posting_versions)
  end

  def search_params
    permitted_params = %i[updater_name updater_id any_name_matches artist_name artist_id any_other_name_matches group_name is_active]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
