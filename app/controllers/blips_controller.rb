class BlipsController < ApplicationController
  class BlipTooOld < Exception ; end
  respond_to :html, :json
  before_action :member_only, only: [:create, :new, :update, :edit, :hide]
  before_action :moderator_only, only: [:unhide, :destroy]

  rescue_from BlipTooOld, with: :blip_too_old

  def index
    @blips = Blip.visible.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@blips)
  end

  def show
    @blip = Blip.find(params[:id])
    check_privilege(@blip)
    @parent = @blip.response_to
    @children = Blip.visible.where('response_to = ?', @blip.id).paginate(params[:page])
    respond_with(@blip)
  end

  def edit
    @blip = Blip.find(params[:id])
    check_edit_privilege(@blip)
    respond_with(@blip)
  end

  def update
    @blip = Blip.find(params[:id])
    check_edit_privilege(@blip)
    Blip.transaction do
      @blip.update(blip_params(:update))
      ModAction.log(:blip_update, {blip_id: @blip.id, user_id: @blip.creator_id})
    end
    flash[:notice] = 'Blip updated'
    respond_with(@blip)
  end

  def hide
    @blip = Blip.find(params[:id])
    check_hide_privilege(@blip)

    Blip.transaction do
      @blip.update(is_hidden: true)
      ModAction.log(:blip_hide, {blip_id: @blip.id, user_id: @blip.creator_id})
    end
    respond_with(@blip)
  end

  def unhide
    @blip = Blip.find(params[:id])
    Blip.transaction do
      @blip.update(is_hidden: false)
      ModAction.log(:blip_unhide, {blip_id: @blip.id, user_id: @blip.creator_id})
    end
    respond_with(@blip)
  end

  def destroy
    @blip = Blip.find(params[:id])

    ModAction.log(:blip_delete, {blip_id: @blip.id, user_id: @blip.creator_id})
    @blip.destroy
    flash[:notice] = 'Blip deleted'
    respond_with(@blip) do |format|
      format.html do
        redirect_back(fallback_location: blip_path(id: @blip.response_to))
      end
    end
  end

  def new
    @blip = Blip.new
  end

  def create
    @blip = Blip.create(blip_params(:create))

    flash[:notice] = @blip.valid? ? "Blip posted" : @blip.errors.full_messages.join("; ")
    respond_with(@blip) do |format|
      format.html do
        redirect_back(fallback_location: blips_path)
      end
    end
  end

  private

  def search_params
    params.fetch(:search, {}).permit!
  end

  def blip_params(mode)
    allowed = [:body]
    allowed << :response_to if mode == :create
    params.require(:blip).permit(allowed)
  end

  def blip_too_old
    redirect_back(fallback_location: blips_path, flash: {notice: 'You cannot edit blips more than 5 minutes old'})
  end

  def check_privilege(blip)
    raise User::PrivilegeError unless blip.visible_to?(CurrentUser.user)
  end

  def check_hide_privilege(blip)
    raise User::PrivilegeError unless blip.can_hide?(CurrentUser.user)
  end

  def check_edit_privilege(blip)
    return if CurrentUser.is_moderator?
    raise User::PrivilegeError if blip.creator_id != CurrentUser.id
    raise BlipTooOld if blip.created_at < 5.minutes.ago
  end
end
