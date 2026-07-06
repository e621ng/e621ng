# frozen_string_literal: true

# The consent form POSTs to /oauth/authorize then 302s to the app's redirect_uri,
# and browsers enforce form-action across that redirect chain, so the consent page
# must allow that redirect origin the global CSP would otherwise block. Only added once the
# pre-authorization validates, i.e. once the origin is known to match a registered redirect_uri.
module DoorkeeperAuthorizationCsp
  module_function

  def redirect_origin(redirect_uri)
    uri = URI.parse(redirect_uri.to_s)
    return unless uri.scheme && uri.host

    port = ":#{uri.port}" unless uri.port == uri.default_port
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue URI::InvalidURIError
    nil
  end
end

Rails.application.config.to_prepare do
  Doorkeeper::AuthorizationsController.class_eval do
    content_security_policy do |policy|
      if pre_auth.authorizable?
        origin = DoorkeeperAuthorizationCsp.redirect_origin(pre_auth.redirect_uri)
        policy.form_action(:self, origin) if origin
      end
    end
  end
end
