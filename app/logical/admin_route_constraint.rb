# frozen_string_literal: true

# Gates mounted engines (Sidekiq::Web) that sit outside ApplicationController.
# Reads only the cookie session, so API keys and OAuth tokens never match (E6SEC-502).
class AdminRouteConstraint
  def initialize(require_reauth: true)
    @require_reauth = require_reauth
  end

  def matches?(request)
    session = request.session
    user = User.find_by(id: session[:user_id]) if session[:user_id]
    return false unless user&.is_admin? && SessionLoader.session_token_valid?(session, user)
    return false if IpBan.is_banned?(request.remote_ip)
    !@require_reauth || SessionLoader.recently_authenticated?(session)
  end
end
