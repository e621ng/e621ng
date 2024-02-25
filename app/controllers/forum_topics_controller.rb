# frozen_string_literal: true

class ForumTopicsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, :except => [:index, :show]
  before_action :moderator_only, :only => [:unhide]
  before_action :admin_only, only: [:destroy]
  before_action :normalize_search, :only => :index
  before_action :load_topic, :only => [:edit, :show, :update, :destroy, :hide, :unhide, :subscribe, :unsubscribe]
  before_action :check_min_level, :only => [:show, :edit, :update, :destroy, :hide, :unhide, :subscribe, :unsubscribe]
  skip_before_action :api_check

  def new
    @forum_topic = ForumTopic.new(forum_topic_params)
    @forum_topic.original_post = ForumPost.new(forum_topic_params[:original_post_attributes])
    respond_with(@forum_topic)
  end

  def edit
    check_privilege(@forum_topic)
    respond_with(@forum_topic)
  end

  def index
    params[:search] ||= {}
    params[:search][:order] ||= "sticky" if request.format == Mime::Type.lookup("text/html")

    @query = ForumTopic.permitted.active.search(search_params)
    @query = ForumTopic.permitted.search(search_params) if CurrentUser.is_moderator?
    @forum_topics = @query.paginate(params[:page], :limit => per_page, :search_count => params[:search])

    respond_with(@forum_topics) do |format|
      format.html do
        @forum_topics = @forum_topics.includes(:creator, :updater).load
      end
      format.json do
        render :json => @forum_topics.to_json
      end
    end
  end

  def show
    if request.format == Mime::Type.lookup("text/html")
      @forum_topic.mark_as_read!(CurrentUser.user)
    end
    @forum_posts = ForumPost.includes(topic: [:category]).search(:topic_id => @forum_topic.id).reorder("forum_posts.id").paginate(params[:page])
    @original_forum_post_id = @forum_topic.original_post.id
    respond_with(@forum_topic)
  end

  def create
    @forum_topic = ForumTopic.create(forum_topic_params)
    respond_with(@forum_topic)
  end

  def update
    check_privilege(@forum_topic)
    @forum_topic.assign_attributes(forum_topic_params)
    @forum_topic.save touch: false
    respond_with(@forum_topic)
  end

  def destroy
    check_privilege(@forum_topic)
    @forum_topic.destroy
    flash[:notice] = "Topic deleted"
  end

  def hide
    check_privilege(@forum_topic)
    @forum_topic.hide!
    @forum_topic.create_mod_action_for_hide
    flash[:notice] = "Topic hidden"
    respond_with(@forum_topic)
  end

  def unhide
    check_privilege(@forum_topic)
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
    subscription = ForumSubscription.where(:forum_topic_id => @forum_topic.id, :user_id => CurrentUser.user.id).first
    unless subscription
      ForumSubscription.create(:forum_topic_id => @forum_topic.id, :user_id => CurrentUser.user.id, :last_read_at => @forum_topic.updated_at)
    end
    respond_with(@forum_topic)
  end

  def unsubscribe
    subscription = ForumSubscription.where(:forum_topic_id => @forum_topic.id, :user_id => CurrentUser.user.id).first
    if subscription
      subscription.destroy
    end
    respond_with(@forum_topic)
  end

private
  def per_page
    params[:limit] || 40
  end

  def normalize_search
    if params[:title_matches]
      params[:search] ||= {}
      params[:search][:title_matches] = params.delete(:title_matches)
    end

    if params[:title]
      params[:search] ||= {}
      params[:search][:title] = params.delete(:title)
    end
  end

  def check_privilege(forum_topic)
    if !forum_topic.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def load_topic
    @forum_topic = ForumTopic.includes(:category).find(params[:id])
  end

  def check_min_level
    raise User::PrivilegeError.new unless @forum_topic.visible?(CurrentUser.user)
  end

  def forum_topic_params
    permitted_params = [:title, :category_id, { original_post_attributes: %i[id body] }]
    permitted_params += %i[is_sticky is_locked] if CurrentUser.is_moderator?

    params.fetch(:forum_topic, {}).permit(permitted_params)
  end
end
