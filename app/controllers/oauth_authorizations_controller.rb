# frozen_string_literal: true

class OauthAuthorizationsController < Doorkeeper::AuthorizationsController
  layout "default"

  before_action :reject_if_owner_blocked, only: %i[new create]
  before_action :enforce_minimum_user_level, only: %i[new create]

  def authenticate_resource_owner!
    if CurrentUser.api_key.present? || CurrentUser.oauth_token.present?
      render_expected_error(:forbidden, "This action requires browser authentication")
      return
    end
    super
  end

  private

  # Existing tokens are revoked by Ban#revoke_oauth_credentials.
  def reject_if_owner_blocked
    app = Doorkeeper::Application.by_uid(params[:client_id]) if params[:client_id].present?
    return unless app
    return unless app.owner.is_a?(User) && app.owner.is_blocked?

    redirect_with_oauth_error(
      app,
      error: "access_denied",
      description: "This application's owner is no longer in good standing.",
    )
  end

  def enforce_minimum_user_level
    app = Doorkeeper::Application.by_uid(params[:client_id]) if params[:client_id].present?
    return unless app
    return if app.minimum_user_level.to_i == 0
    return if CurrentUser.user.level >= app.minimum_user_level.to_i

    redirect_with_oauth_error(
      app,
      error: "access_denied",
      description: "Your account level is below the minimum required by this application.",
    )
  end

  def redirect_with_oauth_error(app, error:, description:)
    redirect_uri = params[:redirect_uri].presence || app.redirect_uri.to_s.split.first
    if redirect_uri.blank?
      render(plain: "#{error}: #{description}", status: 403)
      return
    end

    uri = Addressable::URI.parse(redirect_uri)
    uri.query_values = (uri.query_values || {}).merge(
      "error" => error,
      "error_description" => description,
      "state" => params[:state],
    ).compact
    redirect_to(uri.to_s, allow_other_host: true)
  end
end
