# frozen_string_literal: true

class PostRecommendationsController < ApplicationController
  respond_to :json

  def artist
    @original_post = Post.find(params[:id])
    unless Security::Lockdown.post_visible?(@original_post, CurrentUser.user)
      render json: {
        post_id: @original_post.id,
        model_version: "opensearch",
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

    post_data = Cache.fetch("post_recs:#{@original_post.id}:#{params[:limit]}:#{CurrentUser.safe_mode? ? 's' : 'e'}", expires_in: 15.minutes) do
      post_ids = PostSets::Recommended.new(@original_post, limit: params[:limit]).post_ids

      # Matches the format of the recommendation engine
      {
        post_id: @original_post.id,
        model_version: "opensearch",
        order: post_ids,
        results: post_ids.map { |post_id| { post_id: post_id, score: 1, explanation: nil } },
      }
    end

    post_data[:post_data] = Post.where(id: post_data[:order]).map(&:thumbnail_attributes)
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

  def lookup
    @post_ids = params[:post_ids]
                .to_s
                .split(",", 21)
                .filter_map { |post_id| post_id.match?(/\A[1-9]\d*\z/) ? post_id.to_i : nil }
                .uniq
                .first(20)
    @posts = Post.where(id: @post_ids).includes(:uploader)

    render json: @posts.map(&:thumbnail_attributes)
  end
end
