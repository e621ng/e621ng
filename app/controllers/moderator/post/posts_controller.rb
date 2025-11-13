# frozen_string_literal: true

module Moderator
  module Post
    class PostsController < ApplicationController
      before_action :approver_only, except: %i[regenerate_thumbnails regenerate_videos]
      before_action :janitor_only, only: %i[regenerate_thumbnails regenerate_videos ai_check]
      before_action :admin_only, only: [:expunge]
      skip_before_action :api_check

      respond_to :html, :json

      def confirm_delete
        @post = ::Post.find(params[:id])
        @reason = @post.pending_flag&.reason || ""
        @reason = "" if @reason =~ /uploading_guidelines/

        @dnp = @post.avoid_posting_artists
      end

      def delete
        @post = ::Post.find(params[:id])

        if params[:reason].blank?
          flash[:notice] = "You must provide a reason for the deletion"
          return redirect_to(confirm_delete_moderator_post_post_path(@post, q: params[:q].presence))
        end

        if params[:commit] == "Delete"
          @post.delete!(params[:reason])

          # Transfer data to parent
          if @post.parent_id.present?
            @post.copy_sources_to_parent if params[:copy_sources].present?
            @post.copy_tags_to_parent if params[:copy_tags].present?

            if params[:move_favorites].present?
              @post.give_favorites_to_parent
              @post.give_post_sets_to_parent
            end

            @post.parent.save if params[:copy_tags].present? || params[:copy_sources].present? || params[:move_favorites].present?
          end
        end

        redirect_to(post_path(@post, q: params[:q].presence))
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
          @post.give_post_sets_to_parent
        end
        redirect_to(post_path(@post))
      end

      def expunge
        @post = ::Post.find(params[:id])
        @post.expunge!(reason: params[:reason])
        respond_with(@post)
      end

      def regenerate_thumbnails
        @post = ::Post.find(params[:id])
        @post.regenerate_image_samples!
        respond_with(@post)
      end

      def regenerate_videos
        @post = ::Post.find(params[:id])
        raise ::User::PrivilegeError, "Cannot regenerate thumbnails on deleted images" if @post.is_deleted?
        @post.regenerate_video_samples!
        respond_with(@post)
      end

      def ai_check
        @post = ::Post.find(params[:id])
        @ai_result = @post.check_for_ai_content
        redirect_back fallback_location: post_path(@post)
      end
    end
  end
end
