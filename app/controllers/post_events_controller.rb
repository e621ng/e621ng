class PostEventsController < ApplicationController
  respond_to :html, :json

  def index
    @events = PostEvent.find_for_post(params[:post_id])
    respond_with(@events)
  end
end
