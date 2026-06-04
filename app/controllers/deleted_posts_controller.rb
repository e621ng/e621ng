# frozen_string_literal: true

class DeletedPostsController < ApplicationController
  respond_to :html

  def index
    @posts = Post.where(is_deleted: true)
                 .joins(:post_deletions).where(post_deletions: { is_undeleted: false })
                 .includes(:uploader)
                 .order("post_deletions.created_at DESC")
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      @posts = @posts.where(uploader_id: @user.id)
    end
    @posts = @posts.paginate(params[:page])
  end
end
