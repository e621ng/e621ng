# frozen_string_literal: true

module Admin
  class DestroyedPostsController < ApplicationController
    before_action :admin_only
    before_action :is_bd_staff_only, only: %i[update]
    respond_to :html

    def index
      @destroyed_posts = DestroyedPost.search(search_params).paginate(params[:page], limit: params[:limit])
    end

    def show
      redirect_to(admin_destroyed_posts_path(search: { post_id: params[:id] }))
    end

    def update
      @destroyed_post = DestroyedPost.find_by!(post_id: params[:id])
      @destroyed_post.update(dp_params)
      flash[:notice] = dp_params[:notify] == "true" ? "Re-uploads of that post will now notify admins" : "Re-uploads of that post will no longer notify admins"
      redirect_to(admin_destroyed_posts_path)
    end

    private

    def search_params
      permit_search_params(%i[destroyer_id destroyer_name destroyer_ip_addr uploader_id uploader_name uploader_ip_addr post_id md5])
    end

    def dp_params
      params.require(:destroyed_post).permit(:notify)
    end
  end
end
