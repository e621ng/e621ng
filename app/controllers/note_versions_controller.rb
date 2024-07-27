# frozen_string_literal: true

class NoteVersionsController < ApplicationController
  respond_to :html, :json

  def index
    @note_versions = NoteVersion.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@note_versions) do |format|
      format.html { @note_versions = @note_versions.includes(:updater) }
    end
  end

  private

  def search_params
    permitted_params = %i[updater_id updater_name post_id note_id is_active body_matches]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
