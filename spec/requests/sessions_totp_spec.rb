# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TOTP login challenge" do
  include_context "as member"

  let(:secret) { "JBSWY3DPEHPK3PXP" }
  let(:user) { create(:user) }
  let!(:user_totp) { create(:user_totp, user: user, secret: secret) }

  before do
    allow(RateLimiter).to receive(:new).and_return(instance_double(RateLimiter, throttled?: false, hit!: 1))
  end

  # Step-aligned instant so code validity doesn't depend on where inside the
  # 30-second TOTP step the spec happens to run.
  around { |example| travel_to(Time.zone.at(1_775_000_010), &example) }

  def login!(extra = {})
    post session_path, params: { session: { name: user.name, password: "hexerade" }.merge(extra) }
  end

  def current_code
    ROTP::TOTP.new(secret).at(Time.now)
  end

  describe "POST /session with 2FA enabled" do
    it "redirects to the challenge without granting a session" do
      login!
      expect(response).to redirect_to(totp_session_path)
      expect(session[:user_id]).to be_nil
      expect(session[:totp_user_id]).to eq(user.id)
      expect(response.cookies["remember"]).to be_nil
    end

    it "does not stamp login tracking before the second factor" do
      expect { login! }.not_to(change { user.reload.last_logged_in_at })
    end

    it "returns 401 totp_required with the challenge url for JSON logins" do
      post session_path(format: :json), params: { session: { name: user.name, password: "hexerade" } }
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["code"]).to eq("totp_required")
      expect(response.parsed_body["url"]).to eq(totp_session_path)
    end

    it "still rejects a wrong password outright" do
      post session_path, params: { session: { name: user.name, password: "wrong" } }
      expect(response).to redirect_to(new_session_path)
      expect(session[:totp_user_id]).to be_nil
    end
  end

  describe "GET /session/totp" do
    it "renders the challenge form during a live challenge" do
      login!
      get totp_session_path
      expect(response).to have_http_status(:ok)
    end

    it "bounces to login without a challenge" do
      get totp_session_path
      expect(response).to redirect_to(new_session_path)
    end

    it "server-renders a single plain totp[code] field, with no JS-only restrictions baked in" do
      login!
      get totp_session_path

      # Progressive-enhancement contract: OtpCodeInput applies inputmode/pattern itself
      # once it enhances the field (maxlength is never applied at all, even by JS - see
      # OtpCodeInput). If inputmode/pattern/maxlength ever end up server-rendered, a JS
      # failure would block backup-code entry. autocomplete stays server-rendered since
      # it's safe/correct in the no-JS baseline and is the password-manager/browser OTP
      # autofill contract.
      assert_select "input[name='totp[code]'][type='text']", 1
      assert_select "input[name='totp[code]'][autocomplete='one-time-code']", 1
      assert_select "input[name='totp[code]'][maxlength]", false
      assert_select "input[name='totp[code]'][pattern]", false
      assert_select "input[name='totp[code]'][inputmode]", false
    end
  end

  describe "POST /session/verify_totp" do
    it "completes the login with a valid code" do
      login!
      post verify_totp_session_path, params: { totp: { code: current_code } }
      expect(response).to redirect_to(posts_path)
      expect(session[:user_id]).to eq(user.id)
      expect(session[:totp_user_id]).to be_nil
      expect(user.reload.last_logged_in_at).to eq(Time.now)
    end

    it "honors the url and remember flags stashed at the password step" do
      login!(url: "/artists", remember: "true")
      post verify_totp_session_path, params: { totp: { code: current_code } }
      expect(response).to redirect_to("/artists")
      expect(response.cookies["remember"]).to be_present
    end

    it "rejects a wrong code and keeps the challenge alive" do
      login!
      post verify_totp_session_path, params: { totp: { code: "000000" } }
      expect(response).to redirect_to(totp_session_path)
      expect(session[:user_id]).to be_nil
      expect(session[:totp_user_id]).to eq(user.id)

      follow_redirect!
      expect(response).to have_http_status(:ok)
      assert_select "#auth-error", text: "Verification code was incorrect.", count: 1
      expect(response.body.scan("Verification code was incorrect.").length).to eq(1)

      get totp_session_path
      expect(response.body).not_to include("Verification code was incorrect.")
    end

    it "does not carry an old error into a new challenge" do
      login!
      post verify_totp_session_path, params: { totp: { code: "000000" } }

      delete session_path
      login!
      get totp_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Verification code was incorrect.")
    end

    it "rejects a replayed code" do
      login!
      code = current_code
      post verify_totp_session_path, params: { totp: { code: code } }
      expect(session[:user_id]).to eq(user.id)

      delete session_path
      login!
      post verify_totp_session_path, params: { totp: { code: code } }
      expect(session[:user_id]).to be_nil
    end

    it "expires the challenge after 5 minutes" do
      login!
      travel 6.minutes
      post verify_totp_session_path, params: { totp: { code: current_code } }
      expect(response).to redirect_to(new_session_path)
      expect(session[:user_id]).to be_nil
    end

    it "accepts a backup code once and mails the remaining count" do
      backup_codes = user_totp.regenerate_backup_codes!
      ActionMailer::Base.deliveries.clear

      login!
      expect do
        post verify_totp_session_path, params: { totp: { code: backup_codes.first } }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(session[:user_id]).to eq(user.id)
      expect(user_totp.reload.backup_code_digests.size).to eq(9)

      delete session_path
      login!
      post verify_totp_session_path, params: { totp: { code: backup_codes.first } }
      expect(session[:user_id]).to be_nil
    end

    context "when 2FA is removed mid-challenge" do
      it "completes the login, honoring the stashed url" do
        login!(url: "/artists")
        user_totp.destroy
        post verify_totp_session_path, params: { totp: { code: "irrelevant" } }
        expect(response).to redirect_to("/artists")
        expect(session[:user_id]).to eq(user.id)
        expect(session[:totp_user_id]).to be_nil
      end

      it "completes the login via JSON" do
        login!
        user_totp.destroy
        post verify_totp_session_path(format: :json), params: { totp: { code: "irrelevant" } }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["url"]).to eq(posts_path)
        expect(session[:user_id]).to eq(user.id)
      end
    end

    context "with JSON format (login overlay)" do
      it "returns the redirect url on success" do
        login!(url: "/artists")
        post verify_totp_session_path(format: :json), params: { totp: { code: current_code } }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["url"]).to eq("/artists")
        expect(session[:user_id]).to eq(user.id)
      end

      it "returns 401 for a wrong code" do
        login!
        post verify_totp_session_path(format: :json), params: { totp: { code: "000000" } }
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to match(/incorrect/i)
        expect(session[:totp_user_id]).to eq(user.id)
      end

      it "returns 401 challenge_expired for a stale challenge" do
        login!
        travel 6.minutes
        post verify_totp_session_path(format: :json), params: { totp: { code: current_code } }
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["code"]).to eq("challenge_expired")
      end

      it "returns 429 while rate limited" do
        allow(RateLimiter).to receive(:new).with("totp:#{user.id}", any_args).and_return(instance_double(RateLimiter, throttled?: true))
        login!
        post verify_totp_session_path(format: :json), params: { totp: { code: current_code } }
        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it "rejects even a correct code while rate limited" do
      allow(RateLimiter).to receive(:new).with("totp:#{user.id}", any_args).and_return(instance_double(RateLimiter, throttled?: true))
      login!
      post verify_totp_session_path, params: { totp: { code: current_code } }
      expect(response).to redirect_to(totp_session_path)
      expect(session[:user_id]).to be_nil
    end
  end

  describe "DELETE /session" do
    it "clears a pending challenge" do
      login!
      delete session_path
      expect(session[:totp_user_id]).to be_nil
      expect(session[:totp_expires_at]).to be_nil
    end
  end

  describe "reauthentication" do
    it "walks password confirmation and the challenge back to the original page" do
      login!
      post verify_totp_session_path, params: { totp: { code: current_code } }
      expect(session[:user_id]).to eq(user.id)

      travel 2.hours
      get api_keys_path
      expect(response).to redirect_to(confirm_password_session_path(url: api_keys_path))

      post session_path, params: { session: { name: user.name, password: "hexerade", url: api_keys_path } }
      expect(response).to redirect_to(totp_session_path)

      post verify_totp_session_path, params: { totp: { code: current_code } }
      expect(response).to redirect_to(api_keys_path)

      get api_keys_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "API authentication exemption" do
    let!(:api_key) { create(:api_key, user: user) }

    it "allows login+api_key param authentication without a challenge" do
      get posts_path(format: :json), params: { login: user.name, api_key: api_key.key }
      expect(response).to have_http_status(:ok)
    end

    it "allows basic auth without a challenge" do
      credentials = Base64.strict_encode64("#{user.name}:#{api_key.key}")
      get posts_path(format: :json), headers: { "Authorization" => "Basic #{credentials}" }
      expect(response).to have_http_status(:ok)
    end

    it "allows bearer token authentication without a challenge" do
      application = Doorkeeper::Application.create!(name: "test-client", redirect_uri: "http://localhost/cb", scopes: "full", owner: create(:user))
      token = Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "full")
      get posts_path(format: :json), headers: { "Authorization" => "Bearer #{token.plaintext_token}" }
      expect(response).to have_http_status(:ok)
    end
  end
end
