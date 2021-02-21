module Moderator
  module Post
    class ApprovalsController < ApplicationController
      before_action :approver_only
      skip_before_action :api_check
      respond_to :json

      def create
        post = ::Post.find(params[:post_id])
        @approval = post.approve!
        respond_with do |fmt|
          fmt.json do
            render json: {}, status: 201
          end
        end
      rescue ::Post::ApprovalError => e
        render_expected_error(422, e.message)
      end

      def destroy
        post = ::Post.find(params[:post_id])
        post.unapprove!
        respond_with(nil)
      end
    end
  end
end
