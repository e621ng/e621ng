# frozen_string_literal: true

module Moderator
  module Post
    class ApprovalsController < ApplicationController
      before_action :approver_only
      skip_before_action :api_check
      respond_to :json

      def create
        post = ::Post.find(params[:post_id])
        if post.is_approvable?
          post.approve!
          respond_with do |fmt|
            fmt.json do
              render json: {}, status: 201
            end
          end
        elsif post.approver.present?
          flash[:notice] = "Post is already approved"
        else
          flash[:notice] = "You can't approve this post"
        end
      end

      def destroy
        post = ::Post.find(params[:post_id])
        if post.is_unapprovable?(CurrentUser.user)
          post.unapprove!
          respond_with(nil)
        else
          flash[:notice] = "You can't unapprove this post"
        end
      end
    end
  end
end
