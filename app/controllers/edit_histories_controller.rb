class EditHistoriesController < ApplicationController
  respond_to :html
  before_action :moderator_only

  def index
    @edit_history = EditHistory.search(search_params).includes(:user).paginate(params[:page], limit: params[:limit])
    respond_with(@edit_history)
  end

  def show
    @edit_history = EditHistory.includes(:user).where(versionable_id: params[:id], versionable_type: params[:type]).paginate(params[:page], limit: params[:limit])
    @content_edits = @edit_history.select(&:is_contentful?)
    respond_with(@edit_history)
  end

  def search_params
    permitted_params = %i[versionable_type versionable_id edit_type user_id user_name]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
