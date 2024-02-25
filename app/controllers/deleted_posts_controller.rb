# frozen_string_literal: true

class DeletedPostsController < ApplicationController
  respond_to :html

  def index
    if params[:user_id].present?
      @user = User.find(params[:user_id])
      @posts = Post.where(is_deleted: true)
      @posts = @posts.where(uploader_id: @user.id)
      @posts = @posts.includes(:uploader).includes(:flags).where("post_flags.id IS NOT NULL").order(Arel.sql("post_flags.created_at DESC")).paginate(params[:page])
    else
      post_flags = PostFlag.where(is_deletion: true).includes(post: [:uploader, :flags]).order(id: :desc).paginate(params[:page])
      new_opts = { pagination_mode: :numbered, records_per_page: post_flags.records_per_page, total_count: post_flags.total_count, current_page: post_flags.current_page }
      @posts = ::Danbooru::Paginator::PaginatedArray.new(post_flags.map(&:post), new_opts)
    end
  end
end
