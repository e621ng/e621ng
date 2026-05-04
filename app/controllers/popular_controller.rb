# frozen_string_literal: true

class PopularController < ApplicationController
  include JsonResponseHelper

  respond_to :html, :json

  def index
    @post_set = PostSets::Popular.new(params[:date].to_s.presence, params[:scale].to_s.presence)
    @posts = @post_set.posts
    respond_with(@posts) do |format|
      format.json do
        pick_json_format(@post_set.api_posts, legacy: params[:v2] != "true", mode: params[:mode], collection: true)
      end
    end
  end
end
