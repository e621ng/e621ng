# frozen_string_literal: true

class PopularController < ApplicationController
  include JsonResponseHelper

  respond_to :html, :json

  def index
    @post_set = PostSets::Popular.new(params[:date], params[:scale])
    @posts = @post_set.posts
    respond_with(@posts) do |format|
      format.json do
        render_posts_json(PostBlueprint.render_as_hash(@post_set.api_posts), collection: true)
      end
    end
  rescue ArgumentError => e
    render_expected_error(422, e)
  end
end
