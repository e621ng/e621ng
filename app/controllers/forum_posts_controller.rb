# frozen_string_literal: true

class ForumPostsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index show search]
  before_action :moderator_only, only: %i[unhide warning]
  before_action :admin_only, only: [:destroy]
  before_action :load_post, only: %i[edit show update destroy hide unhide warning]
  before_action :check_min_level, only: %i[edit show update destroy hide unhide]
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
    check_editable(@forum_post)
    respond_with(@forum_post)
  end

  def search
  end

  def create
    @forum_post = ForumPost.new(forum_post_params(:create))
    if @forum_post.valid?
      @forum_topic = @forum_post.topic
      check_min_level
      @forum_post.save
      respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: @forum_post.forum_topic_page, anchor: "forum_post_#{@forum_post.id}"))
    else
      respond_with(@forum_post)
    end
  end

  def update
    check_editable(@forum_post)
    @forum_post.update(forum_post_params(:update))
    respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: @forum_post.forum_topic_page, anchor: "forum_post_#{@forum_post.id}"))
  end

  def destroy
    check_editable(@forum_post)
    @forum_post.destroy
    respond_with(@forum_post)
  end

  def hide
    check_hidable(@forum_post)
    @forum_post.hide!
    respond_with(@forum_post)
  end

  def unhide
    check_hidable(@forum_post)
    @forum_post.unhide!
    respond_with(@forum_post)
  end

  def warning
    if params[:record_type] == "unmark"
      @forum_post.remove_user_warning!
    else
      @forum_post.user_warned!(params[:record_type], CurrentUser.user)
    end
    html = render_to_string partial: "forum_posts/forum_post", locals: { forum_post: @forum_post, original_forum_post_id: @forum_post.topic.original_post.id }, formats: [:html]
    render json: { html: html, posts: deferred_posts }
  end

  private

  def load_post
    @forum_post = ForumPost.includes(topic: [:category]).find(params[:id])
    @forum_topic = @forum_post.topic
    raise ActiveRecord::RecordNotFound, "Forum post has no associated topic" if @forum_topic.nil?
  end

  def check_min_level
    raise User::PrivilegeError unless @forum_topic.visible?(CurrentUser.user)
    raise User::PrivilegeError if @forum_topic.is_hidden? && !@forum_topic.can_hide?(CurrentUser.user)
    raise User::PrivilegeError if @forum_post.is_hidden? && !@forum_post.can_hide?(CurrentUser.user)
  end

  def check_editable(forum_post)
    raise User::PrivilegeError unless forum_post.editable_by?(CurrentUser.user)
  end

  def check_hidable(forum_post)
    raise User::PrivilegeError unless forum_post.can_hide?(CurrentUser.user)
  end

  def forum_post_params(context)
    permitted_params = [:body]
    permitted_params += [:topic_id] if context == :create

    params.fetch(:forum_post, {}).permit(permitted_params)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.forums_disabled? && !CurrentUser.is_staff?
  end
end
