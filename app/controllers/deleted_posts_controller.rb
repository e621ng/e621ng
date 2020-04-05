require_relative '../logical/danbooru/paginator/elasticsearch_extensions'
class DeletedPostsController < ApplicationController
  before_action :member_only
  respond_to :html

  def index
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      @posts = Post.where(is_deleted: true)
      @posts = @posts.where('posts.uploader_id = ?', @user.id)
      @posts = @posts.includes(:uploader).includes(:flags).where('post_flags.id IS NOT NULL').order(Arel.sql('post_flags.created_at DESC')).paginate(params[:page])
    else
      @posts = PostFlag.where(is_deletion: true).includes(post: [:uploader, :flags]).order(id: :desc).paginate(params[:page])
      new_opts = {mode: :numbered, per_page: @posts.records_per_page, total: @posts.total_count, current_page: params[:page].to_i || 1}
      @posts = ::Danbooru::Paginator::PaginatedArray.new(@posts.map {|f| f.post},
                                                new_opts
      )
    end
  end
end
