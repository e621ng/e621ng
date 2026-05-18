# frozen_string_literal: true

class ForumPostsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index show search]
  before_action :load_post, only: %i[edit show update destroy hide unhide warning]

  before_action :ensure_can_access, only: %i[edit show update destroy hide unhide warning]
  before_action :ensure_can_edit, only: %i[edit update]
  before_action :ensure_can_hide, only: %i[hide]
  before_action :ensure_can_unhide, only: %i[unhide]
  before_action :ensure_can_warn, only: %i[warning]
  before_action :ensure_can_destroy, only: %i[destroy]
  before_action :ensure_lockdown_disabled, except: %i[index show search]

  skip_before_action :api_check

  def index
    @query = ForumPost.visible(CurrentUser.user).search(search_params)
    @forum_posts = @query
                   .includes(:topic, :creator, :updater)
                   .paginate(params[:page], limit: params[:limit], search_count: params[:search])
    respond_with(@forum_posts)
  end

  def show
    if request.format == "text/html" && @forum_post.id == @forum_post.topic.original_post.id
      redirect_to(forum_topic_path(@forum_post.topic, page: params[:page]))
    else
      respond_with(@forum_post)
    end
  end

  def new
    @forum_post = ForumPost.new(forum_post_params(:create))
    respond_with(@forum_post)
  end

  def edit
    respond_with(@forum_post)
  end

  def search
  end

  def create
    @forum_post = ForumPost.new(forum_post_params(:create))
    if @forum_post.valid?
      @forum_post.save
      respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: @forum_post.forum_topic_page, anchor: "forum_post_#{@forum_post.id}"))
    else
      respond_with(@forum_post)
    end
  end

  def update
    @forum_post.update(forum_post_params(:update))
    respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: @forum_post.forum_topic_page, anchor: "forum_post_#{@forum_post.id}"))
  end

  def destroy
    @forum_post.destroy
    respond_with(@forum_post)
  end

  def hide
    @forum_post.hide!
    respond_with(@forum_post)
  end

  def unhide
    @forum_post.unhide!
    respond_with(@forum_post)
  end

  def warning
    if params[:record_type] == "unmark"
      @forum_post.remove_user_warning!
    else
      @forum_post.user_warned!(params[:record_type], CurrentUser.user)
    end
    @forum_topic = @forum_post.topic
    html = render_to_string partial: "forum_posts/forum_post", locals: { forum_post: @forum_post, original_forum_post_id: @forum_topic.original_post.id }, formats: [:html]
    render json: { html: html, posts: deferred_posts }
  end

  private

  def load_post
    @forum_post = ForumPost.includes(topic: [:category]).find(params[:id])
    raise ActiveRecord::RecordNotFound, "Forum post has no associated topic" if @forum_post.topic.nil?
  end

  def forum_post_params(context)
    permitted_params = [:body]
    permitted_params += [:topic_id] if context == :create

    params.fetch(:forum_post, {}).permit(permitted_params)
  end

  #############################
  ###     Access checks     ###
  #############################

  def ensure_can_access
    raise User::PrivilegeError unless @forum_post.can_access?
  end

  def ensure_can_edit
    raise User::PrivilegeError unless @forum_post.can_edit?
  end

  def ensure_can_hide
    raise User::PrivilegeError unless @forum_post.can_hide?
  end

  def ensure_can_unhide
    raise User::PrivilegeError unless @forum_post.can_unhide?
  end

  def ensure_can_warn
    raise User::PrivilegeError unless @forum_post.can_warn?
  end

  def ensure_can_destroy
    raise User::PrivilegeError unless @forum_post.can_destroy?
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.forums_disabled? && !CurrentUser.user.is_staff?
  end
end
