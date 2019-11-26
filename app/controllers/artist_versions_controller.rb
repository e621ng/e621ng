class ArtistVersionsController < ApplicationController
  before_action :member_only
  respond_to :html, :json

  def index
    @artist_versions = ArtistVersion.search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@artist_versions)
  end

end
