# frozen_string_literal: true

class PostRecommendationsController < ApplicationController
  respond_to :json

  def artist = fetch_recommendations(:artist)
  def tags   = fetch_recommendations(:tags)

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

  private

  def fetch_recommendations(mode)
    model_version = "os.#{mode}"

    @original_post = Post.find(params[:id])
    unless Security::Lockdown.post_visible?(@original_post, CurrentUser.user)
      render json: { post_id: @original_post.id, model_version: model_version, results: [], post_data: [] }
      return
    end

    params[:limit] = params[:limit].present? ? params[:limit].to_i.clamp(1, 20) : 6

    rec_cache_key = [
      "post_recs",
      mode,
      @original_post.id,
      params[:limit],
      CurrentUser.safe_mode? ? "s" : "e",
      Digest::SHA1.hexdigest("#{@original_post.tag_string}:#{@original_post.pool_ids.sort.join(',')}")[0, 8],
    ]

    post_data = Cache.fetch(rec_cache_key.join(":"), expires_in: 15.minutes) do
      post_ids = PostSets::Recommended.new(@original_post, limit: params[:limit], mode: mode).post_ids

      # Matches the format of the recommendation engine
      {
        post_id: @original_post.id,
        model_version: model_version,
        order: post_ids,
        results: post_ids.map { |post_id| { post_id: post_id, score: 1, explanation: nil } },
      }
    end

    posts = Post.where(id: post_data[:order]).includes(:uploader)
    post_data[:post_data] = PostThumbnailBlueprint.render_as_hash(posts, collection: true)
    post_data.delete(:order) # Don't pollute the response with redundant data

    render json: post_data
  end
end
