class PostEventsController < ApplicationController
  respond_to :html, :json

  def index
    @events = PostEventDecorator.decorate_collection(
      PostEvent.includes(:creator).search(search_params).paginate(params[:page], limit: params[:limit])
    )
    respond_with(@events)
  end
end
