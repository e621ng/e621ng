# frozen_string_literal: true

class CommentsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index search show for_post]
  before_action :moderator_only, only: %i[unhide warning]
  before_action :admin_only, only: %i[destroy]
  before_action :ensure_lockdown_disabled, except: %i[index search show for_post]
  skip_before_action :api_check

  def index
    if params[:group_by] == "comment"
      index_by_comment
    else
      index_by_post
    end
  end

  def show
    @comment = Comment.find(params[:id])
    check_visible(@comment)
    @comment_votes = CommentVote.for_comments_and_user([@comment.id], CurrentUser.id)
    respond_with(@comment)
  end

  def search
  end

  def for_post
    @post = Post.find(params[:id])
    @comments = @post.comments.includes(:creator, :updater)
    @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)
    comment_html = render_to_string partial: "comments/partials/show/comment", collection: @comments, locals: { post: @post }, formats: [:html]
    respond_with do |format|
      format.json do
        render json: { html: comment_html, posts: deferred_posts }
      end
    end
  end

  def new
    @comment = Comment.new(comment_params(:create))
    respond_with(@comment)
  end

  def edit
    @comment = Comment.find(params[:id])
    check_editable(@comment)
    respond_with(@comment)
  end

  def create
    @comment = Comment.create(comment_params(:create))
    flash[:notice] = @comment.valid? ? "Comment posted" : @comment.errors.full_messages.join("; ")
    respond_with(@comment) do |format|
      format.html do
        redirect_back fallback_location: @comment.post || comments_path
      end
    end
  end

  def update
    @comment = Comment.find(params[:id])
    check_editable(@comment)
    @comment.update(comment_params(:update))
    respond_with(@comment, location: post_path(@comment.post_id))
  end

  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy
    respond_with(@comment)
  end

  def hide
    @comment = Comment.find(params[:id])
    check_hidable(@comment)
    @comment.hide!
    respond_with(@comment)
  end

  def unhide
    @comment = Comment.find(params[:id])
    check_hidable(@comment)
    @comment.unhide!
    respond_with(@comment)
  end

  def warning
    @comment = Comment.find(params[:id])
    if params[:record_type] == "unmark"
      @comment.remove_user_warning!
    else
      @comment.user_warned!(params[:record_type], CurrentUser.user)
    end
    @comment_votes = CommentVote.for_comments_and_user([@comment.id], CurrentUser.id)
    html = render_to_string partial: "comments/partials/show/comment", locals: { comment: @comment, post: nil }, formats: [:html]
    render json: { html: html, posts: deferred_posts }
  end

  private

  def index_by_post
    tags = params[:tags] || ""
    @posts = Post.includes(comments: %i[creator updater]).tag_match("#{tags} order:comment_bumped").paginate(params[:page], limit: 5, search_count: params[:search])

    @comments = @posts.to_h { |post| [post.id, post.comments.includes(:creator, :updater).recent.reverse] }
    @comment_votes = CommentVote.for_comments_and_user(CurrentUser.id ? @comments.values.flatten.map(&:id) : [], CurrentUser.id)
    respond_with(@posts)
  end

  def index_by_comment
    @comments = Comment.visible(CurrentUser.user)
    @comments = @comments.search(search_params).paginate(params[:page], limit: params[:limit], search_count: params[:search])
    @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)
    respond_with(@comments)
  end

  def check_editable(comment)
    raise User::PrivilegeError unless comment.editable_by?(CurrentUser.user)
  end

  def check_visible(comment)
    raise User::PrivilegeError unless comment.visible_to?(CurrentUser.user)
  end

  def check_hidable(comment)
    raise User::PrivilegeError unless comment.can_hide?(CurrentUser.user)
  end

  def search_params
    permitted_params = %i[body_matches post_id post_tags_match creator_name creator_id post_note_updater_name post_note_updater_id poster_id poster_name is_sticky do_not_bump_post order]
    permitted_params += %i[is_hidden] if CurrentUser.is_moderator?
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def comment_params(context)
    permitted_params = %i[body]
    permitted_params += %i[do_not_bump_post post_id] if context == :create
    permitted_params += %i[is_sticky] if CurrentUser.is_janitor?
    permitted_params += %i[is_hidden] if CurrentUser.is_moderator?

    params.fetch(:comment, {}).permit(permitted_params)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.comments_disabled? && !CurrentUser.is_staff?
  end
end
