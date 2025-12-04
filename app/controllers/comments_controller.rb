# frozen_string_literal: true

class CommentsController < ApplicationController
  include ConditionalSearchCount

  respond_to :html, :json
  before_action :member_only, except: %i[index search show for_post]
  before_action :moderator_only, only: %i[unhide warning]
  before_action :admin_only, only: %i[destroy]
  before_action :ensure_lockdown_disabled, except: %i[index search show for_post]
  skip_before_action :api_check

  def index
    if params[:group_by] == "post"
      index_by_post
    else
      index_by_comment
    end
  end

  def show
    @comment = Comment.find(params[:id])
    check_accessible(@comment, bypass_user_settings: true)
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
    @posts = Post.includes(:uploader).includes(comments: %i[creator updater]).tag_match("#{tags} order:comment_bumped").paginate(params[:page], limit: 5, search_count: params[:search])

    @comments = @posts.to_h { |post| [post.id, post.comments.above_threshold.includes(:creator, :updater).recent.reverse] }
    @comment_votes = CommentVote.for_comments_and_user(CurrentUser.id ? @comments.values.flatten.map(&:id) : [], CurrentUser.id)
    respond_with(@posts)
  end

  def index_by_comment
    # Only enable COUNT for searches that actually narrow results to avoid expensive queries
    search_params_for_count = search_count_params(
      narrowing: %i[id body_matches post_id post_tags_match creator_name creator_id
                    post_note_updater_name post_note_updater_id poster_id poster_name ip_addr],
      falsy: %i[is_hidden],
      truthy: %i[is_sticky],
    )

    @comments = Comment
                .includes(:creator, :updater, post: :uploader)
                .search(search_params)
                .above_threshold
                .paginate(params[:page], limit: params[:limit], search_count: search_params_for_count)
    @comment_votes = CommentVote.for_comments_and_user(@comments.map(&:id), CurrentUser.id)

    if CurrentUser.is_staff?
      ids = @comments&.map(&:id)
      @latest = request.params.merge(page: "b#{ids[0] + 1}") if ids.present?
    end

    respond_with(@comments)
  end

  def check_accessible(comment, bypass_user_settings: false)
    raise User::PrivilegeError unless comment.is_accessible?(CurrentUser.user, bypass_user_settings: bypass_user_settings)
  end

  def check_editable(comment)
    raise User::PrivilegeError unless comment.is_accessible?(CurrentUser.user, bypass_user_settings: true) && comment.can_edit?
  end

  def check_hidable(comment)
    raise User::PrivilegeError unless comment.is_accessible?(CurrentUser.user, bypass_user_settings: true) && comment.can_hide?
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
