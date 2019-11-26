class NoteVersionsController < ApplicationController
  respond_to :html, :json

  def index
    @note_versions = NoteVersion.search(search_params).paginate(params[:page], :limit => params[:limit])
    respond_with(@note_versions) do |format|
      format.html { @note_versions = @note_versions.includes(:updater) }
    end
  end
end
