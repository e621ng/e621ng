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

      # Deletes the given post
      # ### Parameters
      # * `dmail` [`String | nil`]: optional DMail body/template. If present, a DMail notifying the
      # uploader of the post's deletion will be sent. Does replace supported variables.
      def delete
        @post = ::Post.find(params[:id])

        if params[:commit] == "Delete"
          # Needs to be in here to prevent `Cancel` from getting rejected w/ empty reason.
          # NOTE: Kinda redundant, as it's checked in `Post.delete!`, but wouldn't surface the error to the user otherwise.
          if params[:reason].blank?
            if @post.pending_flag.nil? || params[:from_flag].blank?
              flash[:notice] = "You must provide a reason for the deletion"
              return redirect_to(confirm_delete_moderator_post_post_path(@post, q: params[:q].presence))
            elsif @post.pending_flag.reason =~ /uploading_guidelines/
              flash[:notice] = "You must directly provide a reason for deletions due to an uploading guidelines flag."
              return redirect_to(confirm_delete_moderator_post_post_path(@post, q: params[:q].presence))
            end
            # Pre-replace the reason so it's not found later
            params[:dmail] = params[:dmail].presence&.gsub("%REASON%", @post.pending_flag.reason)
          end

          if @post.is_deleted?
            respond_to do |format|
              format.html do
                flash[:notice] = "Post ##{@post.id} is already deleted"
                redirect_to(post_path(@post, q: params[:q].presence))
              end
              format.json { render json: { reason: "Post ##{@post.id} is already deleted" }, status: 409 }
            end
            return
          end
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

          if params[:dmail].present?
            Dmail.create_automated({
              to_id: @post.uploader_id,
              title: "Post ##{params[:id]} has been deleted",
              body: params[:dmail]
                .gsub("%POST_ID%", params[:id].to_s)
                .gsub("%STAFF_NAME%", CurrentUser.name)
                .gsub("%STAFF_ID%", CurrentUser.id.to_s)
                .gsub("%UPLOADER_ID%", @post.uploader_id.to_s)
                .gsub("%REASON%", params[:reason].to_s),
            })
          end
        end

        respond_with(@post) do |format|
          format.html { redirect_to(post_path(@post, q: params[:q].presence)) }
        end
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
