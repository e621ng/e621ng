# frozen_string_literal: true

class PoolOrdersController < ApplicationController
  respond_to :html, :json
  before_action :member_only

  def edit
    @pool = Pool.find(params[:pool_id])
    @posts = @pool.posts.limit(Danbooru.config.pool_post_limit(nil)).to_a
    Post.preload_stats!(@posts)
    respond_with(@pool)
  end
end
