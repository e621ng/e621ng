# frozen_string_literal: true

class EditHistoriesController < ApplicationController
  respond_to :html, :json
  before_action :moderator_only

  def index
    @edit_history = EditHistory.includes(:user).search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@edit_history)
  end

  def show
    @edits = EditHistory.includes(:user).where("versionable_id = ? AND versionable_type = ?", params[:id], params[:type]).order(:id)
    respond_with(@edits)
  end

  private

  def search_params
    permitted_params = %i[body_matches subject_matches versionable_type versionable_id editor_name editor_id order]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
