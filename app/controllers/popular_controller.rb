# frozen_string_literal: true

class PopularController < ApplicationController
  respond_to :html, :json

  def index
    @post_set = PostSets::Popular.new(params[:date], params[:scale])
    @posts = @post_set.posts
    respond_with(@posts)
  end
end
