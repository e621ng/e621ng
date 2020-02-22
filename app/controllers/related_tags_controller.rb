class RelatedTagsController < ApplicationController
  respond_to :json, :html, only: [:show]
  respond_to :json, only: [:bulk]
  before_action :member_only

  def show
    @query = RelatedTagQuery.new(query: params[:query], category: params[:category], user: CurrentUser.user)
    expires_in 30.second
    respond_with(@query)
  end

  def bulk
    @query = BulkRelatedTagQuery.new(query: params[:query], category: params[:category], user: CurrentUser.user)
    respond_with(@query) do |fmt|
      fmt.json do
        render json: @query.to_json
      end
    end
  end
end
