class RelatedTagsController < ApplicationController
  respond_to :json, :html, only: [:show]
  respond_to :json, only: [:bulk]
  before_action :member_only

  def show
    @related_tags = RelatedTagQuery.new(query: params[:search][:query], category_id: params[:search][:category_id])
    expires_in 30.seconds
    respond_with(@related_tags)
  end

  def bulk
    @related_tags = BulkRelatedTagQuery.new(query: params[:query], category_id: params[:category_id])
    respond_with(@related_tags) do |fmt|
      fmt.json do
        render json: @related_tags.to_json
      end
    end
  end
end
