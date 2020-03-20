class PostFlagsController < ApplicationController
  before_action :member_only, :except => [:index, :show]
  before_action :janitor_only, only: [:destroy]
  respond_to :html, :json

  def new
    @post_flag = PostFlag.new(post_flag_params)
    @post = Post.find(params[:post_flag][:post_id])
    respond_with(@post_flag)
  end

  def index
    @post_flags = PostFlag.search(search_params).includes(:creator, post: [:flags, :uploader, :approver])
    @post_flags = @post_flags.paginate(params[:page], limit: params[:limit])
    respond_with(@post_flags)
  end

  def create
    @post_flag = PostFlag.create(post_flag_params)
    respond_with(@post_flag) do |fmt|
      fmt.html do
        if @post_flag.errors.size > 0
          @post = Post.find(params[:post_flag][:post_id])
          respond_with(@post_flag)
          else
            redirect_to post_path(id: @post_flag.post_id)
        end
      end
    end
  end

  def destroy
    @post = Post.find(params[:post_id])
    @post.unflag!
    if params[:approval] == 'unapprove'
      @post.unapprove!
    elsif params[:approval] == 'approve'
      @post.approve!
    end
    respond_with(nil)
  end

  def show
    @post_flag = PostFlag.find(params[:id])
    respond_with(@post_flag) do |fmt|
      fmt.html {redirect_to post_flags_path(search: {id: @post_flag.id})}
    end
  end

  private

  def post_flag_params
    params.fetch(:post_flag, {}).permit(%i[post_id reason_name user_reason parent_id])
  end
end
