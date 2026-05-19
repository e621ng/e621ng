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
          steps: steps_with_user_values(@user),
        }
      end
    end
  end

  def complete
    respond_to do |format|
      format.json { render json: { success: true, redirect_url: posts_path } }
    end
  end

  def restart
    redirect_to(onboarding_path, notice: "You have restarted the onboarding process")
  end

  private

  def onboarding_steps
    Danbooru.config.onboarding_steps
  end

  def steps_with_user_values(user)
    onboarding_steps.map do |step|
      step_with_values = step.dup

      case step[:type]
      when "blacklist"
        current_blacklist = user.blacklisted_tags.to_s.split(/\s+/)
        step_with_values[:current_value] = current_blacklist
      when "settings"
        step_with_values[:fields] = step[:fields].map do |field|
          field_dup = field.dup

          if Danbooru.config.allowed_onboarding_fields.include?(field[:id].to_s)
            field_dup[:current_value] = user.public_send(field[:id])
          else
            Rails.logger.error("Field #{field[:id]} is not allowed in onboarding steps. Please add it to Danbooru.config.allowed_onboarding_fields if you want to use it.")
            field_dup[:current_value] = nil
          end

          field_dup
        end
      end

      step_with_values
    end
  end
end
