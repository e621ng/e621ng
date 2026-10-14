# frozen_string_literal: true

class UploadKarmaEventsController < ApplicationController
  respond_to :html, :json

  def index
    @events = UploadKarmaEvent.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@events) do |format|
      format.html { @events = @events.includes(:user, :creator) }
      format.json { render json: UploadKarmaEventBlueprint.render(@events) }
    end
  end
end
