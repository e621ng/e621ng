# frozen_string_literal: true

class EditHistoriesController < ApplicationController
  respond_to :html, :json
  before_action :moderator_only

  def index
    @edit_history = EditHistory.includes(:user).paginate(params[:page], limit: params[:limit])
    respond_with(@edit_history)
  end

  def show
    @edits = EditHistory.includes(:user).where('versionable_id = ? AND versionable_type = ?', params[:id], params[:type]).order(:id)
    respond_with(@edits)
  end
end
