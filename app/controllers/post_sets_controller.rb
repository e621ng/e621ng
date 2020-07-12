class PostSetsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: [:index, :atom, :show]

  def index
    if !params[:post_id].blank?
      if CurrentUser.is_admin?
        @post_sets = PostSet.where_has_post(params[:post_id].to_i).paginate(params[:page], limit: 50)
      else
        @post_sets = PostSet.visible(CurrentUser.user).where_has_post(params[:post_id].to_i).paginate(params[:page], limit: 50)
      end
    elsif !params[:maintainer_id].blank?
      if CurrentUser.is_admin?
        @post_sets = PostSet.where_has_maintainer(params[:maintainer_id].to_i).paginate(params[:page], limit: 50)
      else
        @post_sets = PostSet.visible(CurrentUser.user).where_has_maintainer(CurrentUser.id).paginate(params[:page], limit: 50)
      end
    else
      @post_sets = PostSet.visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])
    end

    respond_with(@post_sets)
  end

  def atom
    begin
      @post_sets = PostSet.visible.order(id: :desc).limit(32)
      headers["Content-Type"] = "application/atom+xml"
    rescue RuntimeError => e
      @post_sets = []
    end

    render layout: false
  end

  def new
    @post_set = PostSet.new
  end

  def create
    @post_set = PostSet.create(set_params)
    flash[:notice] = @post_set.valid? ? 'Set created' : @post_set.errors.full_messages.join('; ')
    respond_with(@post_set)
  end

  def show
    @post_set = PostSet.find(params[:id])
    check_view_access(@post_set)

    respond_with(@post_set)
  end

  def edit
    @post_set = PostSet.find(params[:id])
    check_edit_access(@post_set)
    @can_edit = @post_set.is_owner?(CurrentUser) || CurrentUser.is_admin?
    respond_with(@post_set)
  end

  def update
    @post_set = PostSet.find(params[:id])
    check_edit_access(@post_set)
    @post_set.update(set_params)
    flash[:notice] = @post_set.valid? ? 'Set updated.' : @post_set.errors.full_messages.join('; ')

    if CurrentUser.is_admin? && !@post_set.is_owner?(CurrentUser.user)
      if @post_set.saved_change_to_is_public?
        ModAction.log(:set_mark_private, {set_id: @post_set.id, user_id: @post_set.creator_id})
      end

      if @post_set.saved_change_to_watched_attribute?
        Modaction.log(:set_update, {set_id: @post_set.id, user_id: @post_set.creator_id})
      end
    end

    respond_with(@post_set)
  end

  def maintainers
    @post_set = PostSet.find(params[:id])
  end

  def post_list
    @post_set = PostSet.find(params[:id])
    check_edit_access(@post_set)
    respond_with(@post_set)
  end

  def update_posts
    @post_set = PostSet.find(params[:id])
    check_edit_access(@post_set)
    @post_set.update(update_posts_params)
    flash[:notice] = @post_set.valid? ? 'Set posts updated.' : @post_set.errors.full_messages.join('; ')

    redirect_back(fallback_location: post_list_post_set_path(@post_set))
  end

  def destroy
    @post_set = PostSet.find(params[:id])
    unless @post_set.is_owner?(CurrentUser.user) || CurrentUser.is_admin?
      raise User::PrivilegeError
    end
    if CurrentUser.is_admin?
      ModAction.log(:set_delete, {set_id: @post_set.id, user_id: @post_set.creator_id})
    end
    @post_set.destroy
    respond_with(@post_set)
  end

  def for_select
    owned = PostSet.owned(CurrentUser.user).order(:name)
    maintained = PostSet.active_maintainer(CurrentUser.user).order(:name)

    @for_select = {
        "Owned" => owned.map {|x| [x.name.tr("_", " ").truncate(35), x.id]},
        "Maintained" => maintained.map {|x| [x.name.tr("_", " ").truncate(35), x.id]}
    }

    render json: @for_select
  end

  def add_posts
    @post_set = PostSet.find(params[:id])
    check_edit_access(@post_set)
    @post_set.add(params[:post_ids].map(&:to_i))
    @post_set.save
    respond_with(@post_set)
  end

  def remove_posts
    @post_set = PostSet.find(params[:id])
    check_edit_access(@post_set)
    @post_set.remove(params[:post_ids].map(&:to_i))
    @post_set.save
    respond_with(@post_set)
  end

  private

  def check_edit_access(set)
    unless set.is_owner?(CurrentUser.user) || set.is_maintainer?(CurrentUser.user)
      raise User::PrivilegeError
    end
    if !set.is_public && !set.is_owner?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def check_view_access(set)
    unless set.is_public || set.is_owner?(CurrentUser.user) || CurrentUser.is_admin?
      raise User::PrivilegeError
    end
  end

  def set_params
    params.require(:post_set).permit(%i[name shortname description is_public transfer_on_delete])
  end

  def update_posts_params
    params.require(:post_set).permit([:post_ids_string])
  end

  def search_params
    params.fetch(:search, {}).permit!
  end
end
