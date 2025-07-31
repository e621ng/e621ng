# frozen_string_literal: true

class PostSetsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index show]
  before_action :ensure_lockdown_disabled, except: %i[index show]

  def index
    if !params[:post_id].blank?
      if CurrentUser.is_moderator?
        @post_sets = PostSet.where_has_post(params[:post_id].to_i).paginate(params[:page], limit: 50)
      else
        @post_sets = PostSet.visible(CurrentUser.user).where_has_post(params[:post_id].to_i).paginate(params[:page], limit: 50)
      end
    elsif !params[:maintainer_id].blank?
      if CurrentUser.is_moderator?
        @post_sets = PostSet.where_has_maintainer(params[:maintainer_id].to_i).paginate(params[:page], limit: 50)
      else
        @post_sets = PostSet.visible(CurrentUser.user).where_has_maintainer(CurrentUser.id).paginate(params[:page], limit: 50)
      end
    else
      @post_sets = PostSet.visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])
    end

    respond_with(@post_sets)
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
    check_post_edit_access(@post_set)
    respond_with(@post_set)
  end

  def update
    @post_set = PostSet.find(params[:id])
    check_settings_edit_access(@post_set)
    @post_set.update(set_params)
    flash[:notice] = @post_set.valid? ? 'Set updated' : @post_set.errors.full_messages.join('; ')

    unless @post_set.is_owner?(CurrentUser.user)
      if @post_set.saved_change_to_is_public?
        ModAction.log(:set_change_visibility, { set_id: @post_set.id, user_id: @post_set.creator_id, is_public: @post_set.is_public })
      end

      if @post_set.saved_change_to_watched_attributes?
        ModAction.log(:set_update, { set_id: @post_set.id, user_id: @post_set.creator_id })
      end
    end

    respond_with(@post_set)
  end

  def maintainers
    @post_set = PostSet.find(params[:id])
    check_view_access(@post_set)
  end

  def post_list
    @post_set = PostSet.find(params[:id])
    check_post_edit_access(@post_set)
    respond_with(@post_set)
  end

  def update_posts
    @post_set = PostSet.find(params[:id])
    check_post_edit_access(@post_set)

    if @post_set.is_over_limit?(CurrentUser.user)
      flash[:notice] = "This set contains too many posts and can no longer be edited"
    else
      @post_set.update(update_posts_params)
      flash[:notice] = @post_set.valid? ? "Set posts updated" : @post_set.errors.full_messages.join("; ")
    end

    redirect_back(fallback_location: post_list_post_set_path(@post_set))
  end

  def destroy
    @post_set = PostSet.find(params[:id])
    check_settings_edit_access(@post_set)
    if @post_set.creator != CurrentUser.user
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
    check_post_edit_access(@post_set)
    check_set_post_limit(@post_set)
    @post_set.add(add_remove_posts_params.map(&:to_i))
    @post_set.save
    respond_with(@post_set)
  end

  def remove_posts
    @post_set = PostSet.find(params[:id])
    check_post_edit_access(@post_set)
    check_set_post_limit(@post_set)
    @post_set.remove(add_remove_posts_params.map(&:to_i))
    @post_set.save
    respond_with(@post_set)
  end

  private

  def check_settings_edit_access(set)
    unless set.can_edit_settings?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def check_post_edit_access(set)
    unless set.can_edit_posts?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def check_set_post_limit(set)
    if set.is_over_limit?(CurrentUser.user)
      raise "This set contains too many posts and can no longer be edited."
    end
  end

  def check_view_access(set)
    unless set.can_view?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def set_params
    params.require(:post_set).permit(%i[name shortname description is_public transfer_on_delete])
  end

  def update_posts_params
    params.require(:post_set).permit([:post_ids_string])
  end

  def add_remove_posts_params
    params.extract!(:post_ids).permit(post_ids: []).require(:post_ids)
  end

  def search_params
    permitted_params = %i[name shortname creator_id creator_name order]
    permitted_params += %i[is_public] if CurrentUser.is_moderator?
    permit_search_params permitted_params
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.post_sets_disabled? && !CurrentUser.is_staff?
  end
end
