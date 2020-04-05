class DeletedPostsController < ApplicationController
  before_action :member_only
  respond_to :html

  def index
    @posts = Post.where(is_deleted: true)
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      @posts = @posts.where('posts.uploader_id = ?', @user.id)
    end

    @posts = @posts.includes(:uploader).includes(:flags).where('post_flags.id IS NOT NULL').order(Arel.sql('post_flags.created_at DESC')).paginate(params[:page])
  end
end
