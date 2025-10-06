# frozen_string_literal: true

class BlipsController < ApplicationController
  class BlipTooOld < Exception ; end
  respond_to :html, :json
  before_action :member_only, only: %i[create new update edit delete]
  before_action :moderator_only, only: %i[undelete warning]
  before_action :admin_only, only: [:destroy]
  before_action :ensure_lockdown_disabled, except: %i[index show]

  rescue_from BlipTooOld, with: :blip_too_old

  def index
    @blips = Blip.visible.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@blips)
  end

  def show
    @blip = Blip.find(params[:id])
    check_visible(@blip)
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
    @blip.update(blip_params(:update))
    flash[:notice] = 'Blip updated'
    respond_with(@blip)
  end

  def delete
    @blip = Blip.find(params[:id])
    check_delete_privilege(@blip)
    @blip.delete!
    respond_with(@blip)
  end

  def undelete
    @blip = Blip.find(params[:id])
    @blip.undelete!
    respond_with(@blip)
  end

  def destroy
    @blip = Blip.find(params[:id])
    @blip.destroy
    flash[:notice] = "Blip destroyed"
    respond_with(@blip) do |format|
      format.html do
        respond_with(@blip)
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

  def warning
    @blip = Blip.find(params[:id])
    if params[:record_type] == 'unmark'
      @blip.remove_user_warning!
    else
      @blip.user_warned!(params[:record_type], CurrentUser.user)
    end
    html = render_to_string partial: "blips/partials/show/blip", locals: { blip: @blip }, formats: [:html]
    render json: { html: html, posts: deferred_posts }
  end

  private

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

  def check_visible(blip)
    raise User::PrivilegeError unless blip.visible_to?(CurrentUser.user)
  end

  def check_delete_privilege(blip)
    raise User::PrivilegeError unless blip.can_delete?(CurrentUser.user)
  end

  def check_edit_privilege(blip)
    raise BlipTooOld if blip.created_at < 5.minutes.ago && !CurrentUser.is_admin?
    raise User::PrivilegeError unless blip.can_edit?(CurrentUser.user)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.blips_disabled? && !CurrentUser.is_staff?
  end
end
