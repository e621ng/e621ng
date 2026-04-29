# frozen_string_literal: true

class OnboardingsController < ApplicationController
  before_action :logged_in_only
  respond_to :html, :json

  def show
    @user = CurrentUser.user
    respond_to do |format|
      format.html { render :show }
      format.json do
        render json: {
          user_id: @user.id,
          enable_privacy_mode: @user.enable_privacy_mode?,
          disable_user_dmails: @user.disable_user_dmails?,
          receive_email_notifications: @user.receive_email_notifications?
        }
      end
    end
  end

  def complete
    @user = CurrentUser.user
    @user.update!(onboarding_completed: true)
    
    flash[:notice] = "You have completed your onboarding! Enjoy your stay on e621"

    respond_to do |format|
      format.html { redirect_to posts_path }
      format.json { render json: { success: true, redirect_url: posts_path } }
    end
  end

  def restart
    @user = CurrentUser.user
    @user.update!(onboarding_completed: false)
    redirect_to(onboarding_path, notice: "You have restarted the onboarding process")
  end
end
