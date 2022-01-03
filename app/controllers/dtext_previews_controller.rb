class DtextPreviewsController < ApplicationController
  def create
    body = params[:body] || ""
    dtext = helpers.format_text(body, allow_color: CurrentUser.user.is_privileged?)
    render json: { html: dtext, posts: deferred_posts }
  end
end
