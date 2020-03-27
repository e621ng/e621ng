class PostAppealsController < ApplicationController
  #before_action :member_only, :except => [:index, :show]
  before_action :admin_only
  respond_to :html, :json

  def new
    @post_appeal = PostAppeal.new(post_appeal_params)
    respond_with(@post_appeal)
  end

  def index
    @post_appeals = PostAppeal.includes(:creator).search(search_params).includes(post: [:appeals, :uploader, :approver])
    @post_appeals = @post_appeals.paginate(params[:page], limit: params[:limit])
    respond_with(@post_appeals)
  end

  def create
    @post_appeal = PostAppeal.create(post_appeal_params)
    respond_with(@post_appeal) do |fmt|
      fmt.html do
        redirect_to post_path(id: @post_appeal.post_id)
      end
    end
  end

  def show
    @post_appeal = PostAppeal.find(params[:id])
    respond_with(@post_appeal) do |fmt|
      fmt.html { redirect_to post_appeals_path(search: { id: @post_appeal.id }) }
    end
  end

  private

  def post_appeal_params
    params.fetch(:post_appeal, {}).permit(%i[post_id reason])
  end
end
