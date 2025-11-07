# frozen_string_literal: true

class PoolElementsController < ApplicationController
  respond_to :json
  before_action :member_only

  def create
    @pool = Pool.find_by(name: params[:pool_name]) || Pool.find(params[:pool_id])
    raise ActiveRecord::RecordNotFound if @pool.blank?
    @post = Post.find(params[:post_id])
    raise ActiveRecord::RecordNotFound if @post.blank?

    @pool.with_lock do
      @pool.add(@post.id)
      @pool.save
    end

    if @pool.errors.any?
      flash[:notice] = @pool.errors.full_messages.join("; ")
    else
      append_pool_to_session(@pool)
      flash[:notice] = "Post added to pool ##{@pool.id}"
    end

    respond_with(@pool, location: post_path(@post))
  end

  def destroy
    @pool = Pool.find_by(name: params[:pool_name]) || Pool.find(params[:pool_id])
    @post = Post.find(params[:post_id])
    raise ActiveRecord::RecordNotFound if @post.blank?

    @pool.with_lock do
      @pool.remove!(@post)
      @pool.save
    end

    if @pool.errors.any?
      flash[:notice] = @pool.errors.full_messages.join("; ")
    else
      flash[:notice] = "Post removed from pool ##{@pool.id}"
    end

    respond_with(@pool, location: post_path(@post))
  end

  def recent
    pool_ids = session[:recent_pool_ids].to_s.scan(/\d+/)
    unless pool_ids.any?
      render plain: "[]", content_type: "application/json"
      return
    end

    # Fetch pool names, preserving the order
    ids = pool_ids.map(&:to_i)
    names_by_id = Pool.where(id: ids).pluck(:id, :name).to_h
    pools = ids.map { |id| (name = names_by_id[id]) && { id: id, name: name } }.compact

    render json: pools
  end

  private

  def append_pool_to_session(pool)
    recent_pool_ids = session[:recent_pool_ids].to_s.scan(/\d+/)
    recent_pool_ids.delete(pool.id.to_s) # Push to end of list
    recent_pool_ids << pool.id.to_s
    recent_pool_ids = recent_pool_ids.last(5) if recent_pool_ids.size > 5
    session[:recent_pool_ids] = recent_pool_ids.join(",")
  end
end
