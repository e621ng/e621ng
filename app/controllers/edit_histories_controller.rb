class EditHistoriesController < ApplicationController
  respond_to :html
  before_action :moderator_only

  def index
    @edit_histories = EditHistory.search(search_params).includes(:user).paginate(params[:page], limit: params[:limit])
    respond_with(@edit_histories)
  end

  def show
    @edit_histories = EditHistory.includes(:user).where(versionable_id: params[:id], versionable_type: params[:type])
    @original = @edit_histories.original
    @edit_histories = @edit_histories.order(id: :asc).paginate(params[:page], limit: params[:limit])
    @content_edits = @edit_histories.select(&:is_contentful?)
    respond_with(@edit_histories)
  end

  def diff
    if params[:otherversion].blank? || params[:thisversion].blank?
      redirect_back fallback_location: { action: :index }, notice: "You must select two versions to diff"
      return
    end

    @otherversion = EditHistory.find(params[:otherversion])
    @thisversion = EditHistory.find(params[:thisversion])
    redirect_back fallback_location: { action: :index }, notice: "You cannot diff different versionables" if @otherversion.versionable_type != @thisversion.versionable_type || @otherversion.versionable_id != @thisversion.versionable_id
  end

  def search_params
    permitted_params = %i[versionable_type versionable_id edit_type user_id user_name]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end
end
