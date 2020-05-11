class ForumPostsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, :except => [:index, :show, :search]
  before_action :moderator_only, only: [:destroy, :unhide]
  before_action :load_post, :only => [:edit, :show, :update, :destroy, :hide, :unhide]
  before_action :check_min_level, :only => [:edit, :show, :update, :destroy, :hide, :unhide]
  skip_before_action :api_check

  def new
    raise User::PrivilegeError.new("Must be at least 3 days old to create forum posts.") if CurrentUser.younger_than(3.days)
    if params[:topic_id]
      @forum_topic = ForumTopic.find(params[:topic_id])
      raise User::PrivilegeError.new unless @forum_topic.visible?(CurrentUser.user) && @forum_topic.can_reply?(CurrentUser.user)
    end
    if params[:post_id]
      quoted_post = ForumPost.find(params[:post_id])
      raise User::PrivilegeError.new unless quoted_post.topic.visible?(CurrentUser.user) && quoted_post.topic.can_reply?(CurrentUser.user)
    end
    @forum_post = ForumPost.new_reply(params)
    respond_with(@forum_post)
  end

  def edit
    check_privilege(@forum_post)
    respond_with(@forum_post)
  end

  def index
    @query = ForumPost.permitted.active.search(search_params)
    @forum_posts = @query.includes(:topic).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@forum_posts)
  end

  def search
  end

  def show
    if request.format == "text/html" && @forum_post.id == @forum_post.topic.original_post.id
      redirect_to(forum_topic_path(@forum_post.topic, :page => params[:page]))
    else
      respond_with(@forum_post)
    end
  end

  def create
    raise User::PrivilegeError.new("Must be at least 3 days old to create forum posts.") if CurrentUser.younger_than(3.days)
    @forum_post = ForumPost.create(forum_post_params(:create))
    respond_with(@forum_post, :location => forum_topic_path(@forum_post.topic, :page => @forum_post.forum_topic_page, :anchor => "forum_post_#{@forum_post.id}"))
  end

  def update
    check_privilege(@forum_post)
    @forum_post.update(forum_post_params(:update))
    respond_with(@forum_post, :location => forum_topic_path(@forum_post.topic, :page => @forum_post.forum_topic_page, :anchor => "forum_post_#{@forum_post.id}"))
  end

  def destroy
    check_privilege(@forum_post)
    @forum_post.destroy
    respond_with(@forum_post)
  end

  def hide
    check_privilege(@forum_post)
    @forum_post.hide!
    respond_with(@forum_post)
  end

  def unhide
    check_privilege(@forum_post)
    @forum_post.unhide!
    respond_with(@forum_post)
  end

private
  def load_post
    @forum_post = ForumPost.includes(topic: [:category]).find(params[:id])
    @forum_topic = @forum_post.topic
  end

  def check_min_level
    raise User::PrivilegeError.new unless @forum_topic.visible?(CurrentUser.user)
    raise User::PrivilegeError.new if @forum_topic.is_hidden? && !@forum_topic.can_hide?(CurrentUser.user)
    raise User::PrivilegeError.new if @forum_post.is_hidden? && !@forum_post.can_hide?(CurrentUser.user)
  end

  def check_privilege(forum_post)
    if !forum_post.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def forum_post_params(context)
    permitted_params = [:body]
    permitted_params += [:topic_id] if context == :create

    params.require(:forum_post).permit(permitted_params)
  end
end
