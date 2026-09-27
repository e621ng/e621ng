# frozen_string_literal: true

class UserSettingsController < ApplicationController
  respond_to :json
  before_action :logged_in_only
  before_action :verify_expected_user

  def show
    render json: {
      settings: CurrentUser.user.user_setting&.settings || {},
      settings_revision: CurrentUser.user.settings_revision,
    }
  end

  def update
    changes = setting_params.to_h

    invalid_pair = changes.find { |key, value| !UserSetting.valid_value?(key, value) }
    return render_expected_error(422, "Invalid value for #{invalid_pair.first}") if invalid_pair

    revision, settings = UserSetting.apply_changes!(CurrentUser.user, changes)
    render json: { settings: settings, settings_revision: revision }
  end

  private

  def setting_params
    params.require(:settings).permit(*UserSetting::ALLOWED_SETTINGS.keys)
  end

  # Guards against a stale tab whose session now belongs to a different account.
  def verify_expected_user
    return if params[:expected_user_id].to_s == CurrentUser.id.to_s

    render_expected_error(409, "This page's account no longer matches your active session. Please reload the page.")
  end
end
