# frozen_string_literal: true

# Doorkeeper has no native refresh-token expiry. With rotation on, each refresh
# mints a new token row, so created_at tracks the last use: rejecting tokens
# older than the window gives a 30-day idle timeout.
#
# The refresh grant never runs authorize_resource_owner_for_client, so the level
# gate is re-checked here too.
module RefreshTokenIdleExpiry
  IDLE_WINDOW = 30.days

  def validate_token
    return false unless super && refresh_token.created_at > IDLE_WINDOW.ago

    app = refresh_token.application
    return true if app.nil?

    resource_owner = User.find_by(id: refresh_token.resource_owner_id)
    app.authorization_denial_reason_for(resource_owner).nil?
  end
end

Doorkeeper::OAuth::RefreshTokenRequest.prepend(RefreshTokenIdleExpiry)
