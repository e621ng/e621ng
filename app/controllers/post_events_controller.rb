# frozen_string_literal: true

class PostEventsController < ApplicationController
  include JsonResponseHelper

  respond_to :html, :json

  def index
    @events = PostEventDecorator.decorate_collection(
      PostEvent.includes(:creator).search(search_params).paginate(params[:page], limit: params[:limit]),
    )
    respond_with(@events) do |format|
      format.json do
        render_events_json(PostEventBlueprint.render_as_hash(Draper.undecorate(@events)), legacy: params[:v2] != "true")
      end
    end
  end
end
