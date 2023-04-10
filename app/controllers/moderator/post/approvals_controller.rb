module Moderator
  module Post
    class ApprovalsController < ApplicationController
      before_action :approver_only
      skip_before_action :api_check
      respond_to :json

      def create
        post = ::Post.find(params[:post_id])
        if post.is_approvable?
          post.approve!(resolve_flags: params[:resolve_flags].nil? ? false : params[:resolve_flags].to_s.truthy?)
          respond_with do |fmt|
            fmt.json do
              render json: {}, status: 201
            end
          end
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
