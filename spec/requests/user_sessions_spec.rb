# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSessionsController do
  let(:user) { create(:user) }

  before do
    allow(RateLimiter).to receive(:new).and_return(instance_double(RateLimiter, throttled?: false, hit!: 1, reset!: nil))
  end

  def current_session
    UserSession.find(session[:sid])
  end

  describe "GET /session/active" do
    it "redirects anonymous users to the login page" do
      get user_sessions_path
      expect(response).to redirect_to(new_session_path(url: user_sessions_path))
    end

    it "lists the user's live sessions, marking the current one" do
      make_session(user)
      other = create(:user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.hour.ago, user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15")
      create(:revoked_user_session, user: user, created_at: 2.days.ago, last_seen_at: 1.hour.ago)
      foreign = create(:user_session, created_at: 2.days.ago, last_seen_at: 1.hour.ago)

      get user_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("user-session-#{current_session.id}")
      expect(response.body).to include("This session")
      expect(response.body).to include("user-session-#{other.id}")
      expect(response.body).to include("Safari on macOS")
      expect(response.body).not_to include("user-session-#{foreign.id}")
      expect(response.body).to include("Log out everywhere else")
    end

    it "requires reauthentication when the login is old" do
      travel_to(2.hours.ago) { make_session(user) }
      get user_sessions_path
      expect(response).to redirect_to(confirm_password_session_path(url: user_sessions_path))
    end

    it "is refused with API credentials or a bearer token" do
      key = create(:api_key, user: user)
      get user_sessions_path(format: :json), params: { login: user.name, api_key: key.key }
      expect(response).to have_http_status(:forbidden)

      app = Doorkeeper::Application.create!(name: "sessions-page", redirect_uri: "http://localhost/cb", scopes: "openid full", owner: user)
      token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id, scopes: "openid full")
      get user_sessions_path, headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /session/active/:id" do
    before { make_session(user) }

    it "revokes another session of the same user" do
      other = create(:user_session, user: user)
      delete user_session_path(other)
      expect(response).to redirect_to(user_sessions_path)
      expect(other.reload.revoked_reason).to eq("user")
    end

    it "refuses to revoke the current session" do
      delete user_session_path(current_session)
      expect(response).to have_http_status(:unprocessable_content)
      expect(current_session).to be_active
    end

    it "does not find another user's session" do
      foreign = create(:user_session)
      delete user_session_path(foreign)
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload).to be_active
    end
  end

  describe "DELETE /session/active/revoke_others" do
    it "revokes every other session and keeps the current one" do
      make_session(user)
      others = create_list(:user_session, 2, user: user)

      delete revoke_others_user_sessions_path

      expect(response).to redirect_to(user_sessions_path)
      expect(flash[:notice]).to eq("Logged out 2 other sessions")
      expect(others.map { |s| s.reload.revoked_reason }).to all(eq("others"))
      expect(current_session).to be_active
      get user_sessions_path
      expect(response).to have_http_status(:ok)
    end
  end
end
