# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    if session[:user_id]
      User.find_by(id: session[:user_id])
    else
      session[:url] = request.fullpath
      redirect_to(new_session_path)
      nil
    end
  end

  grant_flows %w[authorization_code]

  pkce_code_challenge_methods ["S256"]
  force_pkce

  default_scopes :openid
  optional_scopes :profile, :email, :full

  access_token_expires_in 15.minutes
  # Rotation requires the previous_refresh_token column from the migration.
  use_refresh_token

  enable_application_owner confirmation: true

  authorize_resource_owner_for_client do |app, resource_owner|
    reason = if app.owner.is_a?(User) && app.owner.is_restricted?
               "This application's owner is no longer in good standing."
             elsif app.minimum_user_level.to_i > 0 && resource_owner&.level.to_i < app.minimum_user_level.to_i
               "You do not have access to this application."
             end
    app.authorization_denial_reason = reason if reason
    reason.nil?
  end

  force_ssl_in_redirect_uri Rails.env.production?

  skip_authorization do |resource_owner, client|
    requested = client.scopes.to_a
    Doorkeeper::AccessToken
      .where(application_id: client.application.id, resource_owner_id: resource_owner.id, revoked_at: nil)
      .any? { |token| (requested - token.scopes.to_a).empty? }
  end

  base_controller "ApplicationController"
end
