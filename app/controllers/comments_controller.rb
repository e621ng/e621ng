class CommentsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, :except => [:index, :search, :show]
  before_action :moderator_only, only: [:unhide, :destroy]
  skip_before_action :api_check

  def index
    if params[:group_by] == "comment" || request.format == Mime::Type.lookup("application/atom+xml")
      index_by_comment
    else
      index_by_post
    end
  end

  def search
  end

  def for_post
    @post = Post.find(params[:id])
    @comments = @post.comments
    @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)
    comment_html = render_to_string partial: 'comments/partials/show/comment.html', collection: @comments, formats: [:html]
    render json: {html: comment_html, posts: deferred_posts}
  end

  def new
    @comment = Comment.new(comment_params(:create))
    @comment.body = Comment.find(params[:id]).quoted_response if params[:id]
    respond_with(@comment)
  end

  def update
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    @comment.update(comment_params(:update))
    respond_with(@comment, :location => post_path(@comment.post_id))
  end

  def create
    @comment = Comment.create(comment_params(:create))
    flash[:notice] = @comment.valid? ? "Comment posted" : @comment.errors.full_messages.join("; ")
    respond_with(@comment) do |format|
      format.html do
        redirect_back fallback_location: (@comment.post || comments_path)
      end
    end
  end

  def edit
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    respond_with(@comment)
  end

  def show
    @comment = Comment.find(params[:id])
    check_visible(@comment)
    @comment_votes = CommentVote.for_comments_and_user([@comment.id], CurrentUser.id)
    respond_with(@comment)
  end

  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy
    respond_with(@comment)
  end

  def hide
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    @comment.hide!
    respond_with(@comment)
  end

  def unhide
    @comment = Comment.find(params[:id])
    check_privilege(@comment)
    @comment.unhide!
    respond_with(@comment)
  end

private
  def index_by_post
    tags = params[:tags] || ""
    @posts = Post.tag_match(tags + " order:comment_bumped").paginate(params[:page], :limit => 5, :search_count => params[:search])
    comment_ids = @posts.flat_map {|post| post.comments.visible(CurrentUser.user).recent.reverse.map(&:id)} if CurrentUser.id
    @comment_votes = CommentVote.for_comments_and_user(comment_ids || [], CurrentUser.id)
    respond_with(@posts)
  end

  def index_by_comment
    @comments = Comment
    @comments = @comments.undeleted unless CurrentUser.is_moderator?
    @comments = @comments.search(search_params).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)
    respond_with(@comments) do |format|
      format.atom do
        @comments = @comments.includes(:post, :creator).load
      end
    end
  end

  def check_privilege(comment)
    if !comment.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def check_visible(comment)
    if !comment.visible_to?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def comment_params(context)
    permitted_params = %i[body post_id]
    permitted_params += %i[do_not_bump_post] if context == :create
    permitted_params += %i[is_sticky is_hidden] if CurrentUser.is_moderator?

    params.fetch(:comment, {}).permit(permitted_params)
  end
end
