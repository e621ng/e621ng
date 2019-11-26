class SourcesController < ApplicationController
  respond_to :js, :json

  def show
    @source = Sources::Strategies.find(params[:url], params[:ref])

    respond_with(@source.to_h) do |format|
      format.json { render json: @source.to_h.to_json }
    end
  end
end
