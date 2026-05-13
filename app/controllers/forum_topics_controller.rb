# frozen_string_literal: true

class ForumTopicsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index show]
  before_action :normalize_search_params, only: [:index]
  before_action :load_topic, only: %i[edit show update destroy hide unhide subscribe unsubscribe]

  before_action :ensure_can_access, only: %i[show edit update destroy hide unhide subscribe unsubscribe]
  before_action :ensure_can_edit, only: %i[edit update]
  before_action :ensure_can_hide, only: %i[hide]
  before_action :ensure_can_unhide, only: %i[unhide]
  before_action :ensure_can_destroy, only: %i[destroy]
  before_action :ensure_lockdown_disabled, except: %i[index show]

  skip_before_action :api_check

  def index
    params[:search] = {} unless params[:search].is_a?(ActionController::Parameters)
    params[:search][:order] ||= "sticky" if request.format == Mime::Type.lookup("text/html")

    @query = ForumTopic.visible(CurrentUser.user).search(search_params)
    @forum_topics = @query
                    .includes(:creator, :updater)
                    .paginate(params[:page], limit: per_page, search_count: params[:search])

    respond_with(@forum_topics)
  end

  def show
    if request.format == Mime::Type.lookup("text/html")
      @forum_topic.mark_as_read!(CurrentUser.user)
    end
    @forum_posts = ForumPost.permitted(CurrentUser.user)
                            .includes(topic: [:category])
                            .includes(:creator, :updater)
                            .search(topic_id: @forum_topic.id)
                            .reorder("forum_posts.id")
                            .paginate(params[:page])

    # Determine which posts are associated with AIBURs
    if request.format.html?
      ids = @forum_posts.map(&:id).flatten
      @votable_posts = [
        TagAlias.where(forum_post_id: ids).pluck(:forum_post_id),
        TagImplication.where(forum_post_id: ids).pluck(:forum_post_id),
        BulkUpdateRequest.where(forum_post_id: ids).pluck(:forum_post_id),
      ].flatten

      @original_forum_post_id = @forum_topic.original_post.id
    end

    respond_with(@forum_topic)
  end

  def new
    @forum_topic = ForumTopic.new(forum_topic_params)
    @forum_topic.original_post = ForumPost.new(forum_topic_params[:original_post_attributes])
    respond_with(@forum_topic)
  end

  def edit
    respond_with(@forum_topic)
  end

  def create
    @forum_topic = ForumTopic.create(forum_topic_params)
    respond_with(@forum_topic)
  end

  def update
    @forum_topic.assign_attributes(forum_topic_params)
    @forum_topic.save
    respond_with(@forum_topic)
  end

  def destroy
    @forum_topic.destroy
    if @forum_topic.errors.none?
      flash[:notice] = "Topic destroyed"
    else
      flash[:notice] = @forum_topic.errors.full_messages.join("; ")
    end
    respond_with(@forum_topic)
  end

  def hide
    @forum_topic.hide!
    @forum_topic.create_mod_action_for_hide
    flash[:notice] = "Topic hidden"
    respond_with(@forum_topic)
  end

  def unhide
    @forum_topic.unhide!
    @forum_topic.create_mod_action_for_unhide
    flash[:notice] = "Topic unhidden"
    respond_with(@forum_topic)
  end

  def mark_all_as_read
    CurrentUser.user.update_attribute(:last_forum_read_at, Time.now)
    ForumTopicVisit.prune!(CurrentUser.user)
    respond_to do |format|
      format.html { redirect_to forum_topics_path, notice: "All topics marked as read" }
      format.json
    end
  end

  def subscribe
    subscription = ForumSubscription.where(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id).first
    unless subscription
      ForumSubscription.create(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id, last_read_at: @forum_topic.updated_at)
    end
    respond_with(@forum_topic)
  end

  def unsubscribe
    subscription = ForumSubscription.where(forum_topic_id: @forum_topic.id, user_id: CurrentUser.user.id).first
    subscription&.destroy
    respond_with(@forum_topic)
  end

  private

  def per_page
    params[:limit] || 40
  end

  def normalize_search_params
    if params[:title_matches].is_a?(String)
      params[:search] = ActionController::Parameters.new unless params[:search].is_a?(ActionController::Parameters)
      params[:search][:title_matches] = params.delete(:title_matches)
    end

    if params[:title].is_a?(String)
      params[:search] = ActionController::Parameters.new unless params[:search].is_a?(ActionController::Parameters)
      params[:search][:title] = params.delete(:title)
    end
  end

  def forum_topic_params
    permitted_params = [:title, :category_id, { original_post_attributes: %i[id body] }]
    permitted_params += %i[is_sticky is_locked] if CurrentUser.is_moderator?

    params.fetch(:forum_topic, {}).permit(permitted_params)
  end

  def load_topic
    @forum_topic = ForumTopic.includes(:category).find(params[:id])
  end

  #############################
  ###     Access checks     ###
  #############################

  def ensure_can_access
    raise User::PrivilegeError unless @forum_topic.can_access?
  end

  def ensure_can_edit
    raise User::PrivilegeError unless @forum_topic.can_edit?
  end

  def ensure_can_hide
    raise User::PrivilegeError unless @forum_topic.can_hide?
  end

  def ensure_can_unhide
    raise User::PrivilegeError unless @forum_topic.can_unhide?
  end

  def ensure_can_destroy
    raise User::PrivilegeError unless @forum_topic.can_destroy?
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.forums_disabled? && !CurrentUser.user.is_staff?
  end
end
