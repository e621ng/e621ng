# frozen_string_literal: true

class BulkUpdateRequestsController < ApplicationController
  respond_to :html, :json
  before_action :member_only, except: %i[index show]
  before_action :admin_only, only: [:approve]
  before_action :load_bulk_update_request, except: %i[new create index]
  before_action :ensure_lockdown_disabled, except: %i[index show]

  def new
    @bulk_update_request = BulkUpdateRequest.new
    respond_with(@bulk_update_request)
  end

  def create
    @bulk_update_request = BulkUpdateRequest.create(bur_params(:create))
    respond_with(@bulk_update_request)
  end

  def show
    @bulk_update_request = BulkUpdateRequest.find(params[:id])
    respond_with(@bulk_update_request)
  end

  def edit
  end

  def update
    if @bulk_update_request.editable?(CurrentUser.user)
      @bulk_update_request.should_validate = true
      @bulk_update_request.update(bur_params(:update))
      flash[:notice] = "Bulk update request updated"
      respond_with(@bulk_update_request)
    else
      access_denied
    end
  end

  def approve
    @bulk_update_request.approve!(CurrentUser.user)
    if @bulk_update_request.errors.size > 0
      flash[:notice] = @bulk_update_request.errors.full_messages.join(";")
    else
      flash[:notice] = "Bulk update approved"
    end
    respond_with(@bulk_update_request)
  end

  def destroy
    if @bulk_update_request.rejectable?(CurrentUser.user)
      @bulk_update_request.reject!(CurrentUser.user)
      flash[:notice] = "Bulk update request rejected"
      respond_with(@bulk_update_request, location: bulk_update_requests_path)
    else
      access_denied
    end
  end

  def index
    @bulk_update_requests = BulkUpdateRequest.search(search_params).includes(:forum_post, :user, :approver).paginate(params[:page], limit: params[:limit])
    respond_with(@bulk_update_requests)
  end

  private

  def load_bulk_update_request
    @bulk_update_request = BulkUpdateRequest.find(params[:id])
  end

  def bur_params(context)
    permitted_params = %i[script]
    permitted_params += %i[title reason forum_topic_id] if context == :create
    permitted_params += %i[skip_forum] if CurrentUser.is_admin?
    permitted_params += %i[forum_topic_id forum_post_id] if context == :update && CurrentUser.is_admin?

    params.require(:bulk_update_request).permit(permitted_params)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.aiburs_disabled? && !CurrentUser.is_staff?
  end
end
