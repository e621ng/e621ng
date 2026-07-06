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
    reason = app.authorization_denial_reason_for(resource_owner)
    app.authorization_denial_reason = reason if reason
    reason.nil?
  end

  # Require HTTPS redirect URIs in production, except loopback IPs for native apps (RFC 8252).
  force_ssl_in_redirect_uri do |uri|
    Rails.env.production? && %w[127.0.0.1 [::1]].exclude?(uri.host)
  end

  skip_authorization do |resource_owner, client|
    requested = client.scopes.to_a
    Doorkeeper::AccessToken
      .where(application_id: client.application.id, resource_owner_id: resource_owner.id, revoked_at: nil)
      .any? { |token| (requested - token.scopes.to_a).empty? }
  end

  base_controller "ApplicationController"
end
