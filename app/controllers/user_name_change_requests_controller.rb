# frozen_string_literal: true

class UserNameChangeRequestsController < ApplicationController
  before_action :member_only, only: [:new, :create, :show]
  before_action :moderator_only, only: :index
  respond_to :html, :json

  def new
    @change_request = UserNameChangeRequest.new(change_request_params)
    respond_with(@change_request)
  end

  def create
    @change_request = UserNameChangeRequest.create(change_request_params)

    if @change_request.errors.any?
      render action: "new"
    else
      @change_request.approve!
      redirect_to user_name_change_request_path(@change_request), notice: "Your name has been changed"
    end
  end

  def show
    @change_request = UserNameChangeRequest.find(params[:id])
    check_privileges!(@change_request)
    respond_with(@change_request)
  end

  def index
    @change_requests = UserNameChangeRequest.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@change_requests)
  end

  private

  def check_privileges!(change_request)
    return if CurrentUser.is_moderator?
    raise User::PrivilegeError if change_request.user_id != CurrentUser.user.id
  end

  def change_request_params
    params.fetch(:user_name_change_request, {}).permit(%i[desired_name change_reason])
  end
end
