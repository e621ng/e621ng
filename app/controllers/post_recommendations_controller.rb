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

    post_data = Cache.fetch("post_recs:#{@original_post.id}:#{params[:limit]}:#{CurrentUser.safe_mode? ? 's' : 'e'}", expires_in: 15.minutes) do
      posts = PostSets::Recommended.new(@original_post, limit: params[:limit]).posts

      # Matches the format of the recommendation engine
      {
        post_id: @original_post.id,
        model_version: "opensearch",
        results: posts.map { |post| { post_id: post.id, score: 1, explanation: nil } },
        post_data: PostBlueprint.render_as_hash(posts),
      }
    end

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
