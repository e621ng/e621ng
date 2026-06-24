# frozen_string_literal: true

require "rails_helper"

RSpec.describe OauthApplicationsController do
  let(:staff)  { create(:staff_user) }
  let(:member) { create(:user) }

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
      get "/applications"
      expect(response).to redirect_to(/session/)
    end

    it "denies below-staff members with 403" do
      sign_in_as(member)
      get "/applications"
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects api_key auth (browser-only)" do
      api_user = create(:staff_user)
      api_key = create(:api_key, user: api_user)
      get "/applications", params: { login: api_user.name, api_key: api_key.key }
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects bearer auth (browser-only)" do
      bearer_user = create(:staff_user)
      app = Doorkeeper::Application.create!(
        name: "for-bearer-rejection", redirect_uri: "http://localhost/cb",
        scopes: "openid full", owner: bearer_user
      )
      token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: bearer_user.id, scopes: "openid full")
      get "/applications", headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff users" do
      sign_in_as(staff, reauthenticated: true)
      get "/applications"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /applications" do
    before { sign_in_as(staff, reauthenticated: true) }

    it "lists every application regardless of owner" do
      mine   = Doorkeeper::Application.create!(name: "StaffOwnedApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: staff)
      theirs = Doorkeeper::Application.create!(name: "OtherOwnedApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: create(:user))

      get "/applications"
      expect(response.body).to include(mine.name)
      expect(response.body).to include(theirs.name)
    end

    it "filters by owner" do
      owner  = create(:user, name: "appOwner")
      mine   = Doorkeeper::Application.create!(name: "StaffOwnedApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: staff)
      theirs = Doorkeeper::Application.create!(name: "OtherOwnedApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: owner)

      get "/applications", params: { search: { owner_name: owner.name } }
      expect(response.body).to include(theirs.name)
      expect(response.body).not_to include(mine.name)
    end
  end

  describe "GET /applications/mine" do
    before { sign_in_as(staff, reauthenticated: true) }

    it "lists only the current user's applications" do
      mine   = Doorkeeper::Application.create!(name: "StaffOwnedApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: staff)
      theirs = Doorkeeper::Application.create!(name: "OtherOwnedApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: create(:user))

      get "/applications/mine"
      expect(response.body).to include(mine.name)
      expect(response.body).not_to include(theirs.name)
    end
  end

  describe "CRUD" do
    before { sign_in_as(staff, reauthenticated: true) }

    it "creates an application owned by the current user" do
      expect do
        post "/applications", params: valid_params
      end.to change(Doorkeeper::Application, :count).by(1)

      app = Doorkeeper::Application.last
      expect(app.owner).to eq(staff)
      expect(app.scopes.to_s).to eq("openid full")
      expect(response).to redirect_to(%r{/applications/})
    end

    it "blocks editing another user's app" do
      other_app = Doorkeeper::Application.create!(name: "other", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: create(:user))
      get "/applications/#{other_app.id}/edit"
      expect(response).to have_http_status(:not_found).or have_http_status(:redirect)
    end

    it "shows another user's app read-only" do
      other_app = Doorkeeper::Application.create!(name: "OtherDetailApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: create(:user))
      get "/applications/#{other_app.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OtherDetailApp")
    end

    it "redirects the owner from show to edit" do
      own = Doorkeeper::Application.create!(name: "OwnDetailApp", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: staff)
      get "/applications/#{own.id}"
      expect(response).to redirect_to(edit_oauth_application_url(own))
    end

    it "enforces the per-user oauth_application_limit on create" do
      cap = staff.oauth_application_limit
      cap.times do |i|
        Doorkeeper::Application.create!(name: "filler-#{i}", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: staff)
      end
      expect do
        post "/applications", params: valid_params
      end.not_to change(Doorkeeper::Application, :count)
      expect(response.body).to include("limit reached")
    end

    it "regenerates the secret" do
      app_record = Doorkeeper::Application.create!(name: "mine", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: staff)
      old_secret = app_record.secret
      post "/applications/#{app_record.id}/regenerate_secret"
      expect(app_record.reload.secret).not_to eq(old_secret)
    end
  end
end
