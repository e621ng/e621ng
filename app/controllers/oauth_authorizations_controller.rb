# frozen_string_literal: true

class OauthAuthorizationsController < Doorkeeper::AuthorizationsController
  layout "default"

  def authenticate_resource_owner!
    if CurrentUser.api_key.present? || CurrentUser.oauth_token.present?
      render_expected_error(:forbidden, "This action requires browser authentication")
      return
    end
    super
  end

  private

  def render_error
    reason = pre_auth.client&.application&.authorization_denial_reason
    if reason
      error = Struct.new(:body).new({ error_description: reason })
      render(:error, locals: { error_response: error }, status: 403)
    else
      super
    end
  end
end
