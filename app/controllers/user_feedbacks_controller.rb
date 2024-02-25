# frozen_string_literal: true

class UserFeedbacksController < ApplicationController
  before_action :moderator_only, :only => [:new, :edit, :create, :update, :destroy]
  respond_to :html, :json

  def new
    @user_feedback = UserFeedback.new(user_feedback_params(:create))
    respond_with(@user_feedback)
  end

  def edit
    @user_feedback = UserFeedback.find(params[:id])
    check_privilege(@user_feedback)
    respond_with(@user_feedback)
  end

  def show
    @user_feedback = UserFeedback.find(params[:id])
    respond_with(@user_feedback)
  end

  def index
    @user_feedbacks = UserFeedback.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@user_feedbacks)
  end

  def create
    @user_feedback = UserFeedback.create(user_feedback_params(:create))
    respond_with(@user_feedback)
  end

  def update
    @user_feedback = UserFeedback.find(params[:id])
    check_privilege(@user_feedback)
    params_update = user_feedback_params(:update)

    @user_feedback.update(params_update)
    not_changed = params_update[:send_update_dmail].to_s.truthy? && !@user_feedback.saved_change_to_body?
    flash[:notice] = "Not sending update, body not changed" if not_changed
    respond_with(@user_feedback)
  end

  def destroy
    @user_feedback = UserFeedback.find(params[:id])
    check_privilege(@user_feedback)
    @user_feedback.destroy
    redirect_back fallback_location: user_feedbacks_path
  end

  private

  def check_privilege(user_feedback)
    raise User::PrivilegeError unless user_feedback.editable_by?(CurrentUser.user)
  end

  def user_feedback_params(context)
    permitted_params = %i[body category]
    permitted_params += %i[user_id user_name] if context == :create
    permitted_params += [:send_update_dmail] if context == :update

    params.fetch(:user_feedback, {}).permit(permitted_params)
  end
end
