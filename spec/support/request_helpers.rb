# frozen_string_literal: true

# Helpers for request specs (type: :request).
#
# Provides a `sign_in_as(user)` method that stubs SessionLoader#load so that
# `CurrentUser.user` is set to the given user for the duration of each example,
# bypassing the real session/cookie/API-key authentication flow.
#
# Usage:
#   sign_in_as create(:admin_user)
#   get "/static/site_map"
#   expect(response).to have_http_status(:ok)
module RequestHelpers
  # Sets up the current user for subsequent requests in the example.
  # Call once per example (or in a before hook). Calling again in the same
  # example replaces the previous stub with the new user.
  def sign_in_as(user)
    loader = instance_double(SessionLoader)
    allow(SessionLoader).to receive(:new).and_return(loader)
    allow(loader).to receive(:load) do
      CurrentUser.user    = user
      CurrentUser.ip_addr = "127.0.0.1"
    end
    allow(loader).to receive(:has_api_authentication?).and_return(false)
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
