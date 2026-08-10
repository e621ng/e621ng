# frozen_string_literal: true

require "rails_helper"

RSpec.describe TotpsController do
  include_context "as member"

  let(:user) { create(:user) }

  before do
    allow(RateLimiter).to receive(:check_limit).and_return(false)
    allow(RateLimiter).to receive(:hit)
  end

  around { |example| travel_to(Time.zone.at(1_775_000_010), &example) }

  def code_for(secret, time = Time.now)
    ROTP::TOTP.new(secret).at(time)
  end

  # Full enrollment through the controller: leaves the user with 2FA enabled and the
  # current request session valid (session[:ph] refreshed).
  def enroll!
    get new_totp_path
    secret = session[:pending_totp_secret]
    post totp_path, params: { totp: { code: code_for(secret) } }
    secret
  end

  describe "access guards" do
    it "redirects anonymous users to the login page" do
      get new_totp_path
      expect(response).to redirect_to(new_session_path(url: new_totp_path))
    end

    it "rejects api key authentication" do
      api_key = create(:api_key, user: user)
      get new_totp_path, params: { login: user.name, api_key: api_key.key }
      expect(response).to have_http_status(:forbidden)
    end

    it "requires recent reauthentication" do
      make_session(user)
      travel 2.hours
      get new_totp_path
      expect(response).to redirect_to(confirm_password_session_path(url: new_totp_path))
    end
  end

  describe "GET /totp" do
    before { make_session(user) }

    it "renders the management page when enrolled" do
      enroll!
      get totp_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Disable two-factor authentication")
    end

    it "redirects to enrollment when not enrolled" do
      get totp_path
      expect(response).to redirect_to(new_totp_path)
    end
  end

  describe "GET /totp/new" do
    before { make_session(user) }

    it "stores a pending secret and renders the enrollment page" do
      get new_totp_path
      expect(response).to have_http_status(:ok)
      expect(session[:pending_totp_secret]).to be_present
      expect(response.body).to include(session[:pending_totp_secret])
    end

    it "renders the management page instead when already enrolled" do
      enroll!
      get new_totp_path
      expect(response).to redirect_to(totp_path)
    end
  end

  describe "POST /totp" do
    before { make_session(user) }

    it "enables 2FA with a valid code, shows backup codes once, and keeps the session alive" do
      get new_totp_path
      secret = session[:pending_totp_secret]
      ActionMailer::Base.deliveries.clear

      expect do
        post totp_path, params: { totp: { code: code_for(secret) } }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
      totp = user.reload.totp
      expect(totp).to be_present
      expect(totp.secret).to eq(secret)
      expect(totp.backup_code_digests.size).to eq(10)
      expect(session[:pending_totp_secret]).to be_nil
      expect(session[:ph]).to eq(user.password_token)

      # The session survives the password_token change.
      get settings_users_path
      expect(response).to have_http_status(:ok)
    end

    it "prevents the enrollment code from being replayed at the login challenge" do
      get new_totp_path
      secret = session[:pending_totp_secret]
      code = code_for(secret)
      post totp_path, params: { totp: { code: code } }

      delete session_path
      post session_path, params: { session: { name: user.name, password: "hexerade" } }
      post verify_totp_session_path, params: { totp: { code: code } }
      expect(session[:user_id]).to be_nil
    end

    it "accepts a code from a slightly fast device clock (+30s step)" do
      get new_totp_path
      secret = session[:pending_totp_secret]
      post totp_path, params: { totp: { code: code_for(secret, 30.seconds.from_now) } }
      expect(response).to have_http_status(:ok)
      expect(user.reload.totp).to be_present
    end

    it "rejects a wrong code, keeping the pending secret and creating nothing" do
      get new_totp_path
      secret = session[:pending_totp_secret]
      post totp_path, params: { totp: { code: "000000" } }
      expect(response).to have_http_status(:ok)
      expect(user.reload.totp).to be_nil
      expect(session[:pending_totp_secret]).to eq(secret)
    end

    it "invalidates other sessions when 2FA is enabled" do
      other = open_session
      other.post session_path, params: { session: { name: user.name, password: "hexerade" } }
      other.get api_keys_path
      expect(other.response).to have_http_status(:ok)

      enroll!
      expect(other.session[:ph]).not_to eq(user.reload.password_token)

      # The stale session[:ph] no longer matches password_token, so the other
      # session is treated as anonymous and bounced to login. The redirect_to
      # matcher inspects the default session's response, so assert manually.
      other.get api_keys_path
      expect(other.response).to have_http_status(:found)
      expect(other.response.redirect_url).to include(new_session_path(url: api_keys_path))
    end
  end

  describe "DELETE /totp" do
    let(:secret) { "JBSWY3DPEHPK3PXP" }

    before do
      allow(UserTotp).to receive(:generate_secret).and_return(secret)
      make_session(user)
      enroll!
      travel 90.seconds
    end

    it "disables 2FA with a valid code" do
      ActionMailer::Base.deliveries.clear
      expect do
        delete totp_path, params: { totp: { code: code_for(secret) } }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(response).to redirect_to(settings_users_path)
      expect(user.reload.totp).to be_nil
    end

    it "accepts a backup code" do
      codes = user.reload.totp.regenerate_backup_codes!
      delete totp_path, params: { totp: { code: codes.first } }
      expect(user.reload.totp).to be_nil
    end

    it "refuses without a valid code" do
      delete totp_path, params: { totp: { code: "000000" } }
      expect(response).to redirect_to(new_totp_path)
      expect(user.reload.totp).to be_present
    end
  end

  describe "POST /totp/regenerate_backup_codes" do
    let(:secret) { "JBSWY3DPEHPK3PXP" }

    before do
      allow(UserTotp).to receive(:generate_secret).and_return(secret)
      make_session(user)
      enroll!
      travel 90.seconds
    end

    it "replaces the backup codes wholesale with a valid code" do
      old_digests = user.reload.totp.backup_code_digests
      post regenerate_backup_codes_totp_path, params: { totp: { code: code_for(secret) } }
      expect(response).to have_http_status(:ok)
      expect(user.reload.totp.backup_code_digests).not_to eq(old_digests)
      expect(user.totp.backup_code_digests.size).to eq(10)
    end

    it "refuses without a valid code" do
      old_digests = user.reload.totp.backup_code_digests
      post regenerate_backup_codes_totp_path, params: { totp: { code: "000000" } }
      expect(response).to redirect_to(new_totp_path)
      expect(user.reload.totp.backup_code_digests).to eq(old_digests)
    end
  end
end
