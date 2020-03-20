class ArtistCommentaryVersionsController < ApplicationController
  respond_to :html, :json
  before_action :admin_only

  def index
    @commentary_versions = ArtistCommentaryVersion.search(search_params).paginate(params[:page], :limit => params[:limit])
    respond_with(@commentary_versions)
  end
end
