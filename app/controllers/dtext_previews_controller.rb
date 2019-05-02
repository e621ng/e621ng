class DtextPreviewsController < ApplicationController
  def create
    @body = params[:body] || ""
    render 'dtext_previews/preview', layout: false
  end
end
