# frozen_string_literal: true

module Maintenance
  module User
    class AvatarsController < ApplicationController
      before_action :member_only

      def edit
        unless CurrentUser.user.avatar_id
          flash[:notice] = "Set an avatar post ID in your settings first"
          redirect_to settings_users_path and return
        end

        @post = Post.find_by(id: CurrentUser.user.avatar_id)

        raise ActiveRecord::RecordNotFound, "Avatar post not found." unless @post
        raise ::User::PrivilegeError, "You do not have permission to edit this avatar." if @post.deleteblocked? || @post.safeblocked?
      end

      def update
        x = params[:avatar_crop_x].presence
        y = params[:avatar_crop_y].presence
        w = params[:avatar_crop_w].presence

        unless x && y && w
          flash[:notice] = "Please draw a crop selection."
          redirect_to edit_maintenance_user_avatar_path and return
        end

        x, y, w = [x, y, w].map(&:to_i)
        post_id = CurrentUser.user.avatar_id

        unless post_id
          flash[:notice] = "Set an avatar post ID in your settings first."
          redirect_to edit_maintenance_user_avatar_path and return
        end

        post = Post.find_by(id: post_id)
        unless post
          flash[:notice] = "Avatar post not found."
          redirect_to edit_maintenance_user_avatar_path and return
        end

        min = Danbooru.config.small_image_width
        source_w = post.sample_width
        source_h = post.sample_height

        unless w >= min && x >= 0 && y >= 0 && x + w <= source_w && y + w <= source_h
          flash[:notice] = "Invalid crop coordinates"
          redirect_to edit_maintenance_user_avatar_path and return
        end

        AvatarCropJob.perform_later(CurrentUser.id, post_id, x, y, w)
        flash[:notice] = "Crop is being processed. It may take a few minutes to complete"
        redirect_to user_path(CurrentUser.user)
      end
    end
  end
end
