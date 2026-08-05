# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthsController do
  include_context "as admin"

  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /auth/login
  # ---------------------------------------------------------------------------

  describe "GET /auth/login" do
    it "returns 200 for anonymous" do
      get login_auth_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get login_auth_path
      expect(response).to have_http_status(:ok)
    end

    it "returns an HTML response" do
      get login_auth_path
      expect(response.content_type).to include("text/html")
    end

    it "returns 406 for JSON format" do
      get login_auth_path(format: :json)
      expect(response).to have_http_status(:not_acceptable)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /auth/totp
  # ---------------------------------------------------------------------------

  describe "GET /auth/totp" do
    let(:totp_user) { create(:user) }

    before do
      create(:user_totp, user: totp_user)
      allow(RateLimiter).to receive(:check_limit).and_return(false)
      allow(RateLimiter).to receive(:hit)
    end

    it "returns 404 without a live challenge" do
      get totp_auth_path
      expect(response).to have_http_status(:not_found)
    end

    it "returns the challenge form during a live challenge" do
      post session_path, params: { session: { name: totp_user.name, password: "hexerade" } }
      get totp_auth_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("auth-totp-form")
    end

    it "returns 404 after the challenge expires" do
      post session_path, params: { session: { name: totp_user.name, password: "hexerade" } }
      travel 6.minutes
      get totp_auth_path
      expect(response).to have_http_status(:not_found)
    end
  end
end
