class PostReplacementsController < ApplicationController
  respond_to :html
  before_action :moderator_only, except: [:index, :create, :new]
  before_action :member_only, only: [:create, :new]

  def new
    @post_replacement = Post.find(params[:post_id]).replacements.new
    respond_with(@post_replacement)
  end

  def create
    @post = Post.find(params[:post_id])
    @post_replacement = @post.replacements.create(create_params.merge(creator_id: CurrentUser.id, creator_ip_addr: CurrentUser.ip_addr))

    flash[:notice] = "Post replacement submitted"
    respond_with(@post_replacement, location: @post)
  end

  def approve
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.approve!

    respond_with(@post_replacement)
  end

  def reject
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.reject!

    respond_with(@post_replacement)
  end

  def destroy
    @post_replacement = PostReplacement.find(params[:id])
    @post_replacement.destroy

    respond_with(@post_replacement)
  end

  def index
    params[:search][:post_id] = params.delete(:post_id) if params.has_key?(:post_id)
    @post_replacements = PostReplacement.search(search_params).paginate(params[:page], limit: params[:limit])

    respond_with(@post_replacements)
  end

private
  def create_params
    params.require(:post_replacement).permit(:replacement_url, :replacement_file, :reason, :source)
  end
end
