module Explore
  class PostsController < ApplicationController
    respond_to :html, :json

    def popular
      @post_set = PostSets::Popular.new(params[:date], params[:scale])
      @posts = @post_set.posts
      respond_with(@posts)
    end

    private

    def allowed_readonly_actions
      super + ["popular"]
    end
  end
end
