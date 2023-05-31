class EditHistoriesController < ApplicationController
  respond_to :html
  before_action :moderator_only

  def index
    @edit_history = EditHistory.includes(:user).paginate(params[:page], limit: params[:limit])
    respond_with(@edit_history)
  end

  def show
    @edit_history = EditHistory.includes(:user).where(versionable_id: params[:id], versionable_type: params[:type]).paginate(params[:page], limit: params[:limit])
    @content_edits = @edit_history.select(&:is_contentful?)
    respond_with(@edit_history)
  end
end
