module Moderator
  module Post
    class PostsController < ApplicationController
      before_action :approver_only
      before_action :janitor_only, only: [:regenerate_thumbnails, :regenerate_videos]
      before_action :admin_only, :only => [:expunge]
      skip_before_action :api_check

      respond_to :html, :json

      def confirm_delete
        @post = ::Post.find(params[:id])
        @reason = @post.flags.where(is_resolved: false)&.last&.reason || ''
        @reason = "Inferior version of post ##{@post.parent_id}." if @post.parent_id && @reason == ''
      end

      def delete
        @post = ::Post.find(params[:id])
        if params[:commit] == "Delete"
          @post.delete!(params[:reason], :move_favorites => params[:move_favorites].present?)
          @post.copy_sources_to_parent if params[:copy_sources].present?
          @post.copy_tags_to_parent if params[:copy_tags].present?
          @post.parent.save if params[:copy_tags].present? || params[:copy_sources].present?
        end
        redirect_to(post_path(@post))
      end

      def undelete
        @post = ::Post.find(params[:id])
        @post.undelete!
        respond_with(@post)
      end

      def confirm_move_favorites
        @post = ::Post.find(params[:id])
      end

      def move_favorites
        @post = ::Post.find(params[:id])
        if params[:commit] == "Submit"
          @post.give_favorites_to_parent
        end
        redirect_to(post_path(@post))
      end

      def expunge
        @post = ::Post.find(params[:id])
        @post.expunge!
        respond_with(@post)
      end

      def regenerate_thumbnails
        @post = ::Post.find(params[:id])
        raise ::User::PrivilegeError.new "Cannot regenerate thumbnails on deleted images" if @post.is_deleted?
        @post.regenerate_image_samples!
        respond_with(@post)
      end

      def regenerate_videos
        @post = ::Post.find(params[:id])
        raise ::User::PrivilegeError.new "Cannot regenerate thumbnails on deleted images" if @post.is_deleted?
        @post.regenerate_video_samples!
        respond_with(@post)
      end
    end
  end
end
