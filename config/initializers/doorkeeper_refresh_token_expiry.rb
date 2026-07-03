# frozen_string_literal: true

# Doorkeeper has no native refresh-token expiry. With rotation on, each refresh
# mints a new token row, so created_at tracks the last use: rejecting tokens
# older than the window gives a 30-day idle timeout.
module RefreshTokenIdleExpiry
  IDLE_WINDOW = 30.days

  def validate_token
    super && refresh_token.created_at > IDLE_WINDOW.ago
  end
end

Doorkeeper::OAuth::RefreshTokenRequest.prepend(RefreshTokenIdleExpiry)
