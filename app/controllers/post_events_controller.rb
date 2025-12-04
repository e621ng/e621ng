# frozen_string_literal: true

class PostEventsController < ApplicationController
  respond_to :html, :json

  def index
    @events = PostEventDecorator.decorate_collection(
      PostEvent.includes(:creator).search(search_params).paginate(params[:page], limit: params[:limit]),
    )
    respond_with(@events) do |format|
      format.json do
        render json: { post_events: PostEventBlueprint.render_as_hash(Draper.undecorate(@events)) }
      end
    end
  end
end
