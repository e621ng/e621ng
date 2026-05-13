# frozen_string_literal: true

class BlipsController < ApplicationController
  class BlipTooOld < StandardError; end
  respond_to :html, :json
  before_action :member_only, only: %i[create new update edit delete]
  before_action :load_blip, only: %i[edit show update delete undelete warning destroy]

  before_action :ensure_can_access, only: %i[show edit update delete undelete warning]
  before_action :ensure_can_edit, only: %i[edit update]
  before_action :ensure_can_delete, only: [:delete]
  before_action :ensure_can_undelete, only: [:undelete]
  before_action :ensure_can_warn, only: [:warning]
  before_action :ensure_can_destroy, only: [:destroy]
  before_action :ensure_lockdown_disabled, except: %i[index show]

  rescue_from BlipTooOld, with: :blip_too_old

  def index
    @blips = Blip.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@blips)
  end

  def show
    @parent = @blip.response_to
    @children = Blip.accessible.where("response_to = ?", @blip.id).paginate(params[:page])
    respond_with(@blip)
  end

  def new
    @blip = Blip.new
  end

  def edit
    respond_with(@blip)
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

  def update
    @blip.update(blip_params(:update))
    flash[:notice] = "Blip updated"
    respond_with(@blip)
  end

  def delete
    if @blip.is_deleted?
      redirect_back(fallback_location: blips_path, flash: { alert: "Blip is already deleted" })
      return
    end

    @blip.delete!
    redirect_back(fallback_location: blips_path, flash: { notice: "Blip deleted" })
  end

  def undelete
    unless @blip.is_deleted?
      redirect_back(fallback_location: blips_path, flash: { alert: "Blip is not deleted" })
      return
    end

    @blip.undelete!
    redirect_back(fallback_location: blips_path, flash: { notice: "Blip undeleted" })
  end

  def warning
    if params[:record_type] == "unmark"
      @blip.remove_user_warning!
    else
      @blip.user_warned!(params[:record_type], CurrentUser.user)
    end
    html = render_to_string partial: "blips/partials/show/blip", locals: { blip: @blip }, formats: [:html]
    render json: { html: html, posts: deferred_posts }
  end

  def destroy
    @blip.destroy
    flash[:notice] = "Blip destroyed"
    respond_with(@blip) do |format|
      format.html do
        respond_with(@blip)
      end
    end
  end

  private

  def load_blip
    @blip = Blip.find(params[:id])
  end

  def search_params
    permitted_params = %i[body_matches response_to creator_name creator_id order]
    permitted_params += %i[ip_addr] if CurrentUser.is_admin?
    permit_search_params permitted_params
  end

  def blip_params(mode)
    allowed = [:body]
    allowed << :response_to if mode == :create
    params.require(:blip).permit(allowed)
  end

  def blip_too_old
    respond_to do |format|
      format.html do
        redirect_back(fallback_location: blips_path, flash: { notice: "You cannot edit blips more than 5 minutes old" })
      end
      format.json do
        render_expected_error(422, "You cannot edit blips more than 5 minutes old")
      end
    end
  end

  #############################
  ###     Access checks     ###
  #############################

  def ensure_can_access
    raise User::PrivilegeError unless @blip.can_access?
  end

  def ensure_can_edit
    # This is technically checked twice: once here to raise BlipTooOld, and once in Blip#can_edit? to
    # raise User::PrivilegeError. This is because BlipTooOld is used to trigger a specific error message
    # in the controller, while User::PrivilegeError is also used to determine which UI buttons to show.
    raise BlipTooOld if @blip.created_at < 5.minutes.ago && !CurrentUser.is_admin?
    raise User::PrivilegeError unless @blip.can_edit?
  end

  def ensure_can_delete
    raise User::PrivilegeError unless @blip.can_delete?
  end

  def ensure_can_undelete
    raise User::PrivilegeError unless @blip.can_undelete?
  end

  def ensure_can_warn
    raise User::PrivilegeError unless @blip.can_warn?
  end

  def ensure_can_destroy
    raise User::PrivilegeError unless @blip.can_destroy?
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.blips_disabled? && !CurrentUser.is_staff?
  end
end
