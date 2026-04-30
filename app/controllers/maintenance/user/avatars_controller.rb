# frozen_string_literal: true

module Maintenance
  module User
    class AvatarsController < ApplicationController
      before_action :member_only

      def edit
        @post = Post.find_by(id: CurrentUser.user.avatar_id)
      end

      def update
        x = params[:avatar_crop_x].presence
        y = params[:avatar_crop_y].presence
        w = params[:avatar_crop_w].presence
        h = params[:avatar_crop_h].presence

        unless x && y && w && h
          flash[:notice] = "Please draw a crop selection."
          redirect_to edit_maintenance_user_avatar_path and return
        end

        x, y, w, h = [x, y, w, h].map(&:to_i)
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

        unless w == h && w >= min && x >= 0 && y >= 0 && x + w <= source_w && y + h <= source_h
          flash[:notice] = "Invalid crop coordinates."
          redirect_to edit_maintenance_user_avatar_path and return
        end

        AvatarCropJob.perform_later(CurrentUser.id, post_id, x, y, w, h)
        flash[:notice] = "Avatar crop is being processed."
        redirect_to edit_maintenance_user_avatar_path
      end
    end
  end
end
