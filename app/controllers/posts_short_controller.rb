# frozen_string_literal: true

class PostsShortController < ApplicationController
  def show
    begin
      post_id = Integer(params[:id], 32)
    rescue ArgumentError
      raise ActiveRecord::RecordNotFound, "Invalid short URL"
    end

    @post = Post.find(post_id)

    respond_to do |format|
      format.html { redirect_to post_path(@post) }
      format.json do
        redirect_to post_path(@post, format: :json)
      end
    end
  end
end
