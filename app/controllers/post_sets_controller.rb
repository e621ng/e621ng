class PostSetsController < ApplicationController
  respond_to :html, :json, :xml
  before_action :member_only, except: [:index, :atom, :show]

  def index
    if !params[:post_id].blank?
      if CurrentUser.is_admin?
        @sets = PostSet.where_has_post(params[:post_id].to_i).paginate(params[:page], limit: 50)
      else
        @sets = PostSet.visible(CurrentUser.user).where_has_post(params[:post_id].to_i).paginate(params[:page], limit: 50)
      end
    elsif !params[:maintainer_id].blank?
      if CurrentUser.is_admin?
        @sets = PostSet.where_has_maintainer(params[:maintainer_id].to_i).paginate(params[:page], limit: 50)
      else
        @sets = PostSet.visible(CurrentUser.user).where_has_maintainer(CurrentUser.id).paginate(params[:page], limit: 50)
      end
    else
      @sets = PostSet.visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])
    end

    respond_with(@sets)
  end

  def atom
    begin
      @sets = PostSet.visible.order(id: :desc).limit(32)
      headers["Content-Type"] = "application/atom+xml"
    rescue RuntimeError => e
      @set = []
    end

    render layout: false
  end

  def new
    @set = PostSet.new
  end

  def create
    @set = PostSet.create(set_params)
    flash[:notice] = @set.valid? ? 'Set created' : @set.errors.full_messages.join('; ')
    respond_with(@set)
  end

  def show
    @set = PostSet.find(params[:id])
    check_view_access(@set)

    respond_with(@set)
  end

  def edit
    @set = PostSet.find(params[:id])
    check_edit_access(@set)
    @can_edit = @set.is_owner?(CurrentUser) || CurrentUser.is_admin?
    respond_with(@set)
  end

  def update
    @set = PostSet.find(params[:id])
    check_edit_access(@set)
    @set.update(set_params)
    flash[:notice] = @set.valid? ? 'Set updated.' : @set.errors.full_messages.join('; ')

    if CurrentUser.is_admin? && !@set.is_owner?(CurrentUser.user)
      if @set.saved_change_to_is_public?
        ModAction.log(:set_mark_private, {set_id: @set.id, user_id: @set.creator_id})
      end

      if @set.saved_change_to_watched_attribute?
        Modaction.log(:set_update, {set_id: @set.id, user_id: @set.creator_id})
      end
    end

    respond_with(@set)
  end

  def maintainers
    @set = PostSet.find(params[:id])
  end

  def post_list
    @set = PostSet.find(params[:id])
    check_edit_access(@set)
    respond_with(@set)
  end

  def update_posts
    @set = PostSet.find(params[:id])
    check_edit_access(@set)
    @set.update(update_posts_params)
    flash[:notice] = @set.valid? ? 'Set posts updated.' : @set.errors.full_messages.join('; ')

    redirect_back(fallback_location: post_list_post_set_path(@set))
  end

  def destroy
    @set = PostSet.find(params[:id])
    unless @set.is_owner?(CurrentUser.user) || CurrentUser.is_admin?
      raise User::PrivilegeError
    end
    if CurrentUser.is_admin?
      ModAction.log(:set_delete, {set_id: @set.id, user_id: @set.user_id})
    end
    @set.destroy
    respond_with(@set)
  end

  def for_select
    owned = PostSet.owned(CurrentUser.user)
    maintained = PostSet.active_maintainer(CurrentUser.user)

    @for_select = {
        "Owned" => owned.map {|x| [x.name.tr("_", " ").truncate(35), x.id]},
        "Maintained" => maintained.map {|x| [x.name.tr("_", " ").truncate(35), x.id]}
    }

    render json: @for_select
  end

  def add_posts
    @set = PostSet.find(params[:id])
    check_edit_access(@set)
    @set.add(params[:post_ids].map(&:to_i))
    @set.save
    respond_with(@set)
  end

  def remove_posts
    @set = PostSet.find(params[:id])
    check_edit_access(@set)
    @set.remove(params[:post_ids].map(&:to_i))
    @set.save
    respond_with(@set)
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
