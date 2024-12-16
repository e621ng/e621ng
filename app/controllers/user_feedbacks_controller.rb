# frozen_string_literal: true

class UserFeedbacksController < ApplicationController
  before_action :moderator_only, except: %i[index show]
  respond_to :html, :json

  def new
    @user_feedback = UserFeedback.new(user_feedback_params(:create))
    respond_with(@user_feedback)
  end

  def edit
    @user_feedback = UserFeedback.find(params[:id])
    check_edit_privilege(@user_feedback)
    respond_with(@user_feedback)
  end

  def show
    @user_feedback = UserFeedback.find(params[:id])
    raise(User::PrivilegeError) if !CurrentUser.user.is_staff? && @user_feedback.is_deleted?
    respond_with(@user_feedback)
  end

  def index
    @user_feedbacks = UserFeedback.visible(CurrentUser.user).search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@user_feedbacks)
  end

  def create
    @user_feedback = UserFeedback.create(user_feedback_params(:create))
    respond_with(@user_feedback)
  end

  def update
    @user_feedback = UserFeedback.find(params[:id])
    check_edit_privilege(@user_feedback)
    params_update = user_feedback_params(:update)

    @user_feedback.update(params_update)
    not_changed = params_update[:send_update_dmail].to_s.truthy? && !@user_feedback.saved_change_to_body?
    flash[:notice] = "Not sending update, body not changed" if not_changed
    respond_with(@user_feedback)
  end

  def delete
    @user_feedback = UserFeedback.find(params[:id])
    check_delete_privilege(@user_feedback)
    @user_feedback.update(is_deleted: true)
    flash[:notice] = @user_feedback.errors.any? ? @user_feedback.errors.full_messages.join("; ") : "Feedback deleted"
    respond_with(@user_feedback) do |format|
      format.html { redirect_back(fallback_location: user_feedbacks_path(search: { user_id: @user_feedback.user_id })) }
    end
  end

  def undelete
    @user_feedback = UserFeedback.find(params[:id])
    check_delete_privilege(@user_feedback)
    @user_feedback.update(is_deleted: false)
    flash[:notice] = @user_feedback.errors.any? ? @user_feedback.errors.full_messages.join("; ") : "Feedback undeleted"
    respond_with(@user_feedback) do |format|
      format.html { redirect_back(fallback_location: user_feedbacks_path(search: { user_id: @user_feedback.user_id })) }
    end
  end

  def destroy
    @user_feedback = UserFeedback.find(params[:id])
    check_destroy_privilege(@user_feedback)
    @user_feedback.destroy
    respond_with(@user_feedback) do |format|
      format.html { redirect_back(fallback_location: user_feedbacks_path(search: { user_id: @user_feedback.user_id })) }
    end
  end

  private

  def check_edit_privilege(user_feedback)
    raise(User::PrivilegeError) unless user_feedback.editable_by?(CurrentUser.user)
  end

  def check_delete_privilege(user_feedback)
    raise(User::PrivilegeError) unless user_feedback.deletable_by?(CurrentUser.user)
  end

  def check_destroy_privilege(user_feedback)
    raise(User::PrivilegeError) unless user_feedback.destroyable_by?(CurrentUser.user)
  end

  def user_feedback_params(context)
    permitted_params = %i[body category]
    permitted_params += %i[user_id user_name] if context == :create
    permitted_params += %i[send_update_dmail] if context == :update

    params.fetch(:user_feedback, {}).permit(permitted_params)
  end

  def search_params
    permitted_params = %i[body_matches user_id user_name creator_id creator_name category]
    permitted_params += %i[deleted] if CurrentUser.is_staff?
    permit_search_params(permitted_params)
  end
end
