# frozen_string_literal: true

class DtextPreviewsController < ApplicationController
  def create
    body = params[:body] || ""
    dtext = helpers.format_text(body, allow_color: params[:allow_color].to_s.truthy?)
    render json: { html: dtext, posts: deferred_posts }
  end
end
