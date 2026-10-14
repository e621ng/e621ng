# frozen_string_literal: true

class PostApprovalsController < ApplicationController
  respond_to :html, :json

  def index
    @search_params = search_params
    @post_approvals = PostApproval.includes(:post, :user).search(@search_params).paginate(params[:page], limit: params[:limit])
    Post.preload_stats!(@post_approvals.map(&:post))
    respond_with(@post_approvals)
  end

  private

  def search_params
    # user_id and user_name are special cased in the model search function
    permitted_params = %i[user_id user_name post_id order]
    permitted_params += %i[post_tags_match] if CurrentUser.is_member?
    permit_search_params permitted_params
  end
end
