# frozen_string_literal: true

require "rails_helper"

RSpec.describe OauthApplicationsController do
  let(:janitor) { create(:janitor_user) }
  let(:member)  { create(:user) }

  let(:valid_params) do
    {
      doorkeeper_application: {
        name: "My App",
        confidential: "1",
        redirect_uris: ["http://localhost/cb"],
        scopes: %w[openid full],
      },
    }
  end

  describe "access gating" do
    it "redirects anonymous users to login" do
      get "/oauth/applications"
      expect(response).to redirect_to(/session/)
    end

    it "denies non-Janitor members with 403" do
      sign_in_as(member)
      get "/oauth/applications"
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects api_key auth (browser-only)" do
      api_user = create(:janitor_user)
      api_key = create(:api_key, user: api_user)
      get "/oauth/applications", params: { login: api_user.name, api_key: api_key.key }
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects bearer auth (browser-only)" do
      bearer_user = create(:janitor_user)
      app = Doorkeeper::Application.create!(
        name: "for-bearer-rejection", redirect_uri: "http://localhost/cb",
        scopes: "openid full", owner: bearer_user
      )
      token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: bearer_user.id, scopes: "openid full")
      get "/oauth/applications", headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows Janitor+ users" do
      sign_in_as(janitor, reauthenticated: true)
      get "/oauth/applications"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "CRUD" do
    before { sign_in_as(janitor, reauthenticated: true) }

    it "creates an application owned by the current user" do
      expect do
        post "/oauth/applications", params: valid_params
      end.to change(Doorkeeper::Application, :count).by(1)

      app = Doorkeeper::Application.last
      expect(app.owner).to eq(janitor)
      expect(app.scopes.to_s).to eq("openid full")
      expect(response).to redirect_to(/oauth.applications/)
    end

    it "scopes index to the current user's applications" do
      mine    = Doorkeeper::Application.create!(name: "mine",    redirect_uri: "http://localhost/cb", scopes: "openid full", owner: janitor)
      theirs  = Doorkeeper::Application.create!(name: "theirs",  redirect_uri: "http://localhost/cb", scopes: "openid full", owner: create(:janitor_user))

      get "/oauth/applications"
      expect(response.body).to include(mine.name)
      expect(response.body).not_to include(theirs.name)
    end

    it "blocks viewing/editing another user's app" do
      other_app = Doorkeeper::Application.create!(name: "other", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: create(:janitor_user))
      get "/oauth/applications/#{other_app.id}/edit"
      expect(response).to have_http_status(:not_found).or have_http_status(:redirect)
    end

    it "enforces the per-user oauth_application_limit on create" do
      cap = janitor.oauth_application_limit
      cap.times do |i|
        Doorkeeper::Application.create!(name: "filler-#{i}", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: janitor)
      end
      expect do
        post "/oauth/applications", params: valid_params
      end.not_to change(Doorkeeper::Application, :count)
      expect(response.body).to include("limit reached")
    end

    it "regenerates the secret" do
      app_record = Doorkeeper::Application.create!(name: "mine", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: janitor)
      old_secret = app_record.secret
      post "/oauth/applications/#{app_record.id}/regenerate_secret"
      expect(app_record.reload.secret).not_to eq(old_secret)
    end
  end
end
