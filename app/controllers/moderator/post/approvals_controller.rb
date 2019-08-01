module Moderator
  module Post
    class ApprovalsController < ApplicationController
      before_action :approver_only
      skip_before_action :api_check
      respond_to :json, :xml, :js

      def create
        cookies.permanent[:moderated] = Time.now.to_i
        post = ::Post.find(params[:post_id])
        @approval = post.approve!
        respond_with(:moderator, @approval)
      end

      def destroy
        post = ::Post.find(params[:post_id])
        post.unapprove!
        respond_with(nil)
      end
    end
  end
end
