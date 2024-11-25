# frozen_string_literal: true

class NoteVersionsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index]

  def index
    @note_versions = NoteVersion.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@note_versions) do |format|
      format.html { @note_versions = @note_versions.includes(:updater) }
    end
  end

  def undo
    can_edit = CurrentUser.can_note_edit_with_reason
    raise(User::PrivilegeError, "User #{User.throttle_reason(can_edit)}") unless can_edit == true
    @note_version = NoteVersion.find(params[:id])
    @note_version.undo!
  end

  private

  def search_params
    permitted_params = %i[updater_id updater_name post_id note_id is_active body_matches]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
