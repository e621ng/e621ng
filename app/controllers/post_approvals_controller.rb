# frozen_string_literal: true

class PostApprovalsController < ApplicationController
  respond_to :html, :json

  def index
    @post_approvals = PostApproval.includes(:post, :user).search(search_params).paginate(params[:page], limit: params[:limit])
    Post.preload_stats!(@post_approvals.map(&:post))
    respond_with(@post_approvals)
  end
end
