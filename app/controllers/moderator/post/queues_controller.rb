module Moderator
  module Post
    class QueuesController < ApplicationController
      respond_to :html, :json
      before_action :approver_only
      skip_before_action :api_check

      def show
        if params[:per_page]
          cookies.permanent["mq_per_page"] = params[:per_page]
        end

        ::Post.without_timeout do
          tags = params[:query] || ''
          tags += " -user:!#{CurrentUser.id}" if params[:hidden]
          tags += " status:modqueue order:id_asc"
          @posts = ::Post.tag_match(tags).paginate(params[:page], limit: per_page, includes: [:disapprovals, :uploader])
          @posts.each # hack to force rails to eager load
        end
        respond_with(@posts)
      end

    protected

      def per_page
        cookies["mq_per_page"] || params[:per_page] || 25
      end
    end
  end
end
