# frozen_string_literal: true

require "rails_helper"

RSpec.describe OauthAuthorizedApplicationsController do
  let(:user) { create(:user) }

  describe "access gating" do
    it "redirects anonymous users to login" do
      get "/oauth/authorized_applications"
      expect(response).to redirect_to(/session/)
    end

    it "rejects api_key auth (browser-only)" do
      api_user = create(:user)
      api_key = create(:api_key, user: api_user)
      get "/oauth/authorized_applications", params: { login: api_user.name, api_key: api_key.key }
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects bearer auth (browser-only) so App A cannot revoke App B" do
      bearer_user = create(:user)
      app = Doorkeeper::Application.create!(
        name: "for-bearer-rejection", redirect_uri: "http://localhost/cb",
        scopes: "openid full", owner: bearer_user
      )
      token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: bearer_user.id, scopes: "openid full")
      get "/oauth/authorized_applications", headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows logged-in browser users" do
      sign_in_as(user)
      get "/oauth/authorized_applications"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /oauth/authorized_applications/:id with bearer auth" do
    let(:bearer_user) { create(:user) }
    let(:other_app) do
      Doorkeeper::Application.create!(
        name: "other-app", redirect_uri: "http://localhost/cb",
        scopes: "openid full", owner: bearer_user
      )
    end
    let(:my_app) do
      Doorkeeper::Application.create!(
        name: "my-app", redirect_uri: "http://localhost/cb",
        scopes: "openid full", owner: create(:user)
      )
    end
    let!(:bearer_token) do
      Doorkeeper::AccessToken.create!(
        application: other_app, resource_owner_id: bearer_user.id, scopes: "openid full",
      )
    end
    let!(:victim_token) do
      Doorkeeper::AccessToken.create!(
        application: my_app, resource_owner_id: bearer_user.id, scopes: "openid full",
      )
    end

    it "rejects so a malicious app cannot silently revoke another grant" do
      delete "/oauth/authorized_applications/#{my_app.id}",
             headers: { "Authorization" => "Bearer #{bearer_token.token}" }
      expect(response).to have_http_status(:forbidden)
      expect(victim_token.reload.revoked?).to be false
    end
  end
end
