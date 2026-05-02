# frozen_string_literal: true

class PostRecommendationsController < ApplicationController
  respond_to :json

  def artist
    @original_post = Post.find(params[:id])
    unless Security::Lockdown.post_visible?(@original_post, CurrentUser.user)
      render json: {
        post_id: @original_post.id,
        model_version: "os.artist",
        results: [],
        post_data: [],
      }
      return
    end

    if params[:limit].present?
      # Don't write random stuff into the cache key
      params[:limit] = params[:limit].to_i.clamp(1, 20)
    else
      params[:limit] = 6
    end

    tag_hash = Digest::SHA1.hexdigest("#{@original_post.tag_string}:#{@original_post.pool_ids.sort.join(',')}")[0, 8]
    post_data = Cache.fetch("post_recs:a:#{@original_post.id}:#{params[:limit]}:#{CurrentUser.safe_mode? ? 's' : 'e'}:#{tag_hash}", expires_in: 15.seconds) do
      post_ids = PostSets::Recommended.new(@original_post, limit: params[:limit]).post_ids

      # Matches the format of the recommendation engine
      {
        post_id: @original_post.id,
        model_version: "os.artist",
        order: post_ids,
        results: post_ids.map { |post_id| { post_id: post_id, score: 1, explanation: nil } },
      }
    end

    posts = Post.where(id: post_data[:order])
    post_data[:post_data] = PostThumbnailBlueprint.render_as_hash(posts, collection: true)
    post_data.delete(:order) # Don't pollute the response with redundant data

    render json: post_data
  end

  def tags
    @original_post = Post.find(params[:id])
    unless Security::Lockdown.post_visible?(@original_post, CurrentUser.user)
      render json: {
        post_id: @original_post.id,
        model_version: "os.tags",
        results: [],
        post_data: [],
      }
      return
    end

    if params[:limit].present?
      # Don't write random stuff into the cache key
      params[:limit] = params[:limit].to_i.clamp(1, 20)
    else
      params[:limit] = 6
    end

    tag_hash = Digest::SHA1.hexdigest("#{@original_post.tag_string}:#{@original_post.pool_ids.sort.join(',')}")[0, 8]
    post_data = Cache.fetch("post_recs:t:#{@original_post.id}:#{params[:limit]}:#{CurrentUser.safe_mode? ? 's' : 'e'}:#{tag_hash}", expires_in: 15.seconds) do
      post_ids = PostSets::Recommended.new(@original_post, limit: params[:limit], mode: :tags).post_ids

      # Matches the format of the recommendation engine
      {
        post_id: @original_post.id,
        model_version: "os.tags",
        order: post_ids,
        results: post_ids.map { |post_id| { post_id: post_id, score: 1, explanation: nil } },
      }
    end

    posts = Post.where(id: post_data[:order])
    post_data[:post_data] = PostThumbnailBlueprint.render_as_hash(posts, collection: true)
    post_data.delete(:order) # Don't pollute the response with redundant data

    render json: post_data
  end

  def remote
    @original_post = Post.find(params[:id])
    unless Security::Lockdown.post_visible?(@original_post, CurrentUser.user)
      render json: {
        post_id: @original_post.id,
        model_version: "not_implemented",
        results: [],
      }
      return
    end

    render json: {
      post_id: @original_post.id,
      model_version: "not_implemented",
      results: [],
    }
  end
end
