# frozen_string_literal: true

require "rails_helper"

# Smoke-tests the OpenID Connect provider endpoints exposed by doorkeeper +
# doorkeeper-openid_connect. Drives the full Authorization Code + PKCE flow
# end-to-end and inspects the resulting JWT id_token.
RSpec.describe "OIDC endpoints" do
  describe "GET /.well-known/openid-configuration" do
    before { get "/.well-known/openid-configuration" }

    it "returns 200" do
      expect(response).to have_http_status(:ok)
    end

    it "advertises the auth-code flow with PKCE S256" do
      doc = response.parsed_body
      expect(doc["grant_types_supported"]).to include("authorization_code", "refresh_token")
      expect(doc["response_types_supported"]).to include("code")
      expect(doc["code_challenge_methods_supported"]).to eq(["S256"])
    end

    it "lists the e621 scopes and claims" do
      doc = response.parsed_body
      expect(doc["scopes_supported"]).to include("openid", "profile", "email", "full")
      expect(doc["claims_supported"]).to include(
        "sub", "preferred_username", "e621_level", "e621_level_string", "email"
      )
    end
  end

  describe "GET /oauth/discovery/keys" do
    before { get "/oauth/discovery/keys" }

    it "returns the JWKS with one RS256 RSA key" do
      expect(response).to have_http_status(:ok)
      keys = response.parsed_body["keys"]
      expect(keys.length).to eq(1)
      expect(keys.first).to include("kty" => "RSA", "alg" => "RS256", "use" => "sig")
      expect(keys.first["kid"]).to be_present
    end
  end

  describe "Authorization Code + PKCE flow" do
    let(:password) { "hexerade" }
    let(:user)     { create(:user) }
    let(:owner)    { create(:user) }
    let(:redirect) { "http://localhost/cb" }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "test-client",
        redirect_uri: redirect,
        scopes: "openid profile email full",
        confidential: true,
        owner: owner,
      )
    end

    let(:verifier)  { SecureRandom.urlsafe_base64(64).delete("=")[0, 64] }
    let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

    def authorize_url(scope:, state: "xyz", nonce: "abc")
      "/oauth/authorize?" + {
        response_type: "code",
        client_id: oauth_app.uid,
        redirect_uri: redirect,
        scope: scope,
        state: state,
        code_challenge: challenge,
        code_challenge_method: "S256",
        nonce: nonce,
      }.to_query
    end

    # Doorkeeper's resource_owner_authenticator reads session[:user_id] directly,
    # which sign_in_as does not populate. Use a real login POST to establish the
    # cookie-backed session.
    before { make_session(user, password) }

    it "anonymous user gets redirected to login" do
      reset!
      get authorize_url(scope: "openid full")
      expect(response).to redirect_to(new_session_path)
    end

    it "renders the styled consent page on first authorize" do
      get authorize_url(scope: "openid profile email full")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("oauth-consent")
      expect(response.body).to include("Act on your behalf")
      expect(response.body).to include("See your username and profile")
      expect(response.body).to include("See your email address")
    end

    it "auto-skips consent when a token with a superset of scopes already exists" do
      Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: user.id,
        scopes: "openid profile email full",
      )
      get authorize_url(scope: "openid full")
      expect(response).to redirect_to(/code=/)
    end

    it "issues an access_token + id_token on code exchange and the id_token verifies against JWKS" do
      # 1) GET authorize: skip_authorization fires (we seed a prior token)
      Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: user.id,
        scopes: "openid profile email full",
      )
      get authorize_url(scope: "openid profile email full")
      expect(response).to have_http_status(:redirect)
      code = response.location[/code=([^&]+)/, 1]
      expect(code).to be_present

      # 2) Exchange code for tokens
      post "/oauth/token", params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect,
        client_id: oauth_app.uid,
        client_secret: oauth_app.plaintext_secret,
        code_verifier: verifier,
      }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["token_type"]).to eq("Bearer")
      expect(body["access_token"]).to be_present
      expect(body["refresh_token"]).to be_present
      expect(body["id_token"]).to be_present
      expect(body["expires_in"]).to eq(15.minutes.to_i)
      expect(body["scope"]).to eq("openid profile email full")

      # 3) Decode + verify the id_token against the JWKS the provider advertises
      pubkey = OidcSigningKey.private_key.public_key
      payload, header = JWT.decode(body["id_token"], pubkey, true, algorithm: "RS256")
      expect(header["kid"]).to be_present
      expect(header["typ"]).to eq("JWT")
      expect(payload["sub"]).to eq(user.id.to_s)
      expect(payload["aud"]).to eq(oauth_app.uid)
      expect(payload["nonce"]).to eq("abc")
      expect(payload["auth_time"]).to be_present

      # 4) Userinfo with the access token returns the requested claims
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{body['access_token']}" }
      expect(response).to have_http_status(:ok)
      info = response.parsed_body
      expect(info).to include(
        "sub" => user.id.to_s,
        "preferred_username" => user.name,
        "email" => user.email,
        "e621_level_string" => user.level_string,
      )
    end

    it "rejects the code on second exchange (single-use)" do
      Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: user.id,
        scopes: "openid full",
      )
      get authorize_url(scope: "openid full")
      code = response.location[/code=([^&]+)/, 1]
      exchange = -> do
        post "/oauth/token", params: {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect,
          client_id: oauth_app.uid,
          client_secret: oauth_app.plaintext_secret,
          code_verifier: verifier,
        }
      end
      exchange.call
      expect(response).to have_http_status(:ok)
      exchange.call
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end

    it "rejects code exchange when the PKCE verifier is wrong" do
      Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: user.id,
        scopes: "openid full",
      )
      get authorize_url(scope: "openid full")
      code = response.location[/code=([^&]+)/, 1]
      post "/oauth/token", params: {
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect,
        client_id: oauth_app.uid,
        client_secret: oauth_app.plaintext_secret,
        code_verifier: "wrong-verifier-#{SecureRandom.hex(8)}",
      }
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end
  end

  describe "/oauth/authorize when the application's owner is banned" do
    let(:password) { "hexerade" }
    let(:user)     { create(:user) }
    let(:owner)    { create(:user) }
    let(:redirect) { "http://localhost/cb" }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "owned-by-soon-banned",
        redirect_uri: redirect,
        scopes: "openid full",
        confidential: true,
        owner: owner,
      )
    end
    let(:verifier)  { SecureRandom.urlsafe_base64(64).delete("=")[0, 64] }
    let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
    let(:authorize_url) do
      "/oauth/authorize?" + {
        response_type: "code", client_id: oauth_app.uid, redirect_uri: redirect,
        scope: "openid full", state: "ban", code_challenge: challenge, code_challenge_method: "S256",
      }.to_query
    end

    before do
      oauth_app # touch so it exists before we ban the owner
      CurrentUser.scoped(create(:moderator_user)) do
        create(:ban, user: owner)
      end
      make_session(user, password)
    end

    it "renders an error page citing the owner" do
      get authorize_url
      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("no longer in good standing")
    end

    it "leaves the application row in place so unban can recover it" do
      expect(Doorkeeper::Application.find_by(id: oauth_app.id)).to be_present
    end
  end

  describe "minimum_user_level gate" do
    let(:password) { "hexerade" }
    let(:owner)    { create(:user) }
    let(:redirect) { "http://localhost/cb" }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "level-gated",
        redirect_uri: redirect,
        scopes: "openid full",
        confidential: true,
        owner: owner,
        minimum_user_level: UserLevel::PRIVILEGED,
      )
    end
    let(:verifier)  { SecureRandom.urlsafe_base64(64).delete("=")[0, 64] }
    let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

    def authorize_url
      "/oauth/authorize?" + {
        response_type: "code",
        client_id: oauth_app.uid,
        redirect_uri: redirect,
        scope: "openid full",
        state: "level-state",
        code_challenge: challenge,
        code_challenge_method: "S256",
        nonce: "n",
      }.to_query
    end

    context "with a Member-level user" do
      let(:user) { create(:user) }

      before { make_session(user, password) }

      it "renders an error page citing the level requirement" do
        get authorize_url
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include("do not have access")
      end
    end

    context "with a Privileged-level user" do
      let(:user) { create(:privileged_user) }

      before { make_session(user, password) }

      it "renders the consent screen normally" do
        get authorize_url
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Authorize level-gated")
      end
    end

    context "with a Janitor-level user (above minimum)" do
      let(:user) { create(:janitor_user) }

      before { make_session(user, password) }

      it "renders the consent screen normally" do
        get authorize_url
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "/oauth/authorize rejects non-browser auth" do
    let(:user) { create(:user) }
    let(:redirect) { "http://localhost/cb" }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "x", redirect_uri: redirect, scopes: "openid full",
        confidential: true, owner: create(:user)
      )
    end
    let(:verifier)  { SecureRandom.urlsafe_base64(64).delete("=")[0, 64] }
    let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
    let(:url) do
      "/oauth/authorize?" + {
        response_type: "code", client_id: oauth_app.uid, redirect_uri: redirect,
        scope: "openid", state: "s", code_challenge: challenge, code_challenge_method: "S256",
      }.to_query
    end

    it "rejects api_key params" do
      key = create(:api_key, user: user)
      get url, params: { login: user.name, api_key: key.key }
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects bearer token" do
      token = Doorkeeper::AccessToken.create!(application: oauth_app, resource_owner_id: user.id, scopes: "openid full")
      get url, headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "revoke then re-authorize" do
    let(:password) { "hexerade" }
    let(:user)     { create(:user) }
    let(:owner)    { create(:user) }
    let(:redirect) { "http://localhost/cb" }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "revoke-test", redirect_uri: redirect,
        scopes: "openid full", confidential: true, owner: owner
      )
    end
    let(:verifier)  { SecureRandom.urlsafe_base64(64).delete("=")[0, 64] }
    let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }

    def authorize_url
      "/oauth/authorize?" + {
        response_type: "code", client_id: oauth_app.uid, redirect_uri: redirect,
        scope: "openid full", state: "rs",
        code_challenge: challenge, code_challenge_method: "S256", nonce: "n",
      }.to_query
    end

    before { make_session(user, password) }

    it "shows consent again after the prior grant is revoked" do
      # Seed a prior grant so skip_authorization fires
      Doorkeeper::AccessToken.create!(
        application: oauth_app, resource_owner_id: user.id, scopes: "openid full",
      )

      get authorize_url
      expect(response).to have_http_status(:redirect),
                          "expected auto-skip on prior superset grant"

      # Revoke via the authorized-applications controller
      delete "/applications/authorized/#{oauth_app.id}"
      expect(response).to have_http_status(:redirect)
      expect(
        Doorkeeper::AccessToken.where(
          application_id: oauth_app.id, resource_owner_id: user.id, revoked_at: nil,
        ),
      ).to be_empty

      # Next authorize should re-show consent, not auto-skip
      get authorize_url
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Authorize revoke-test")
    end
  end

  describe "e621_permissions claim" do
    let(:owner) { create(:user) }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "perm-claim", redirect_uri: "http://localhost/cb",
        scopes: "openid profile", confidential: true, owner: owner
      )
    end

    def claims_for(user)
      token = Doorkeeper::AccessToken.create!(
        application: oauth_app, resource_owner_id: user.id, scopes: "openid profile",
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token.token}" }
      response.parsed_body
    end

    it "lists role flags the user holds" do
      janitor = create(:janitor_user)
      perms = claims_for(janitor)["e621_permissions"]
      expect(perms).to include("is_janitor", "is_member")
      expect(perms).not_to include("is_admin")
    end

    it "lists capability bitflags the user holds" do
      uploader = create(:user)
      uploader.update!(can_upload_free: true)
      perms = claims_for(uploader)["e621_permissions"]
      expect(perms).to include("can_upload_free")
    end

    it "is advertised in the discovery doc" do
      get "/.well-known/openid-configuration"
      expect(response.parsed_body["claims_supported"]).to include("e621_permissions")
    end
  end

  describe "picture claim in safe mode" do
    let(:owner) { create(:user) }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "pic-claim", redirect_uri: "http://localhost/cb",
        scopes: "openid profile", confidential: true, owner: owner
      )
    end

    def picture_for(user)
      token = Doorkeeper::AccessToken.create!(
        application: oauth_app, resource_owner_id: user.id, scopes: "openid profile",
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token.token}" }
      response.parsed_body["picture"]
    end

    it "returns the picture when the avatar post is safe-rated" do
      avatar_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "s") }
      user = create(:user, avatar_id: avatar_post.id, enable_safe_mode: true)
      expect(picture_for(user)).to be_present
    end

    it "suppresses the picture when the avatar post is explicit-rated and user has safe mode on" do
      avatar_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "e") }
      user = create(:user, avatar_id: avatar_post.id, enable_safe_mode: true)
      expect(picture_for(user)).to be_nil
    end

    it "suppresses the picture when the avatar post is questionable-rated and site safe mode is on" do
      avatar_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "q") }
      user = create(:user, avatar_id: avatar_post.id)
      allow(Danbooru.config.custom_configuration).to receive(:safe_mode?).and_return(true)
      expect(picture_for(user)).to be_nil
    end

    it "returns the picture when safe mode is off regardless of rating" do
      avatar_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "e") }
      user = create(:user, avatar_id: avatar_post.id)
      expect(picture_for(user)).to be_present
    end
  end

  describe "email_verified claim" do
    let(:owner) { create(:user) }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "claims-test", redirect_uri: "http://localhost/cb",
        scopes: "openid email", confidential: true, owner: owner
      )
    end

    def userinfo_for(user)
      token = Doorkeeper::AccessToken.create!(
        application: oauth_app, resource_owner_id: user.id, scopes: "openid email",
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token.token}" }
      response.parsed_body
    end

    it "is true for users with a present, verified email" do
      user = create(:user, email: "verified@example.com")
      user.update_columns(email_verification_key: nil)
      expect(userinfo_for(user)["email_verified"]).to be true
    end

    it "is false for users with no email even when no verification is pending" do
      user = create(:user)
      user.update_columns(email: "", email_verification_key: nil)
      expect(userinfo_for(user)["email_verified"]).to be false
    end

    it "is false for users mid-verification" do
      user = create(:user, email: "unverified@example.com")
      user.update_columns(email_verification_key: "pending-token")
      expect(userinfo_for(user)["email_verified"]).to be false
    end
  end

  describe "userinfo email claim scope gating" do
    let(:owner) { create(:user) }
    let(:user) do
      create(:user, email: "scoped@example.com").tap do |u|
        u.update_columns(email_verification_key: nil)
      end
    end
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "scope-test", redirect_uri: "http://localhost/cb",
        scopes: "openid profile email", confidential: true, owner: owner
      )
    end

    def userinfo_with(scopes)
      token = Doorkeeper::AccessToken.create!(
        application: oauth_app, resource_owner_id: user.id, scopes: scopes,
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token.token}" }
      response.parsed_body
    end

    it "includes email and email_verified when the email scope is granted" do
      info = userinfo_with("openid email")
      expect(info).to include("email" => user.email, "email_verified" => true)
    end

    it "omits email and email_verified when the email scope is not granted" do
      info = userinfo_with("openid profile")
      expect(info).not_to have_key("email")
      expect(info).not_to have_key("email_verified")
      expect(info).to include("preferred_username" => user.name)
    end
  end

  describe "PKCE enforcement for public clients" do
    let(:password) { "hexerade" }
    let(:user)     { create(:user) }
    let(:owner)    { create(:user) }
    let(:redirect) { "http://localhost/cb" }
    let(:public_app) do
      Doorkeeper::Application.create!(
        name: "public-client",
        redirect_uri: redirect,
        scopes: "openid full",
        confidential: false,
        owner: owner,
      )
    end

    before { make_session(user, password) }

    it "rejects authorize without code_challenge" do
      get "/oauth/authorize", params: {
        response_type: "code",
        client_id: public_app.uid,
        redirect_uri: redirect,
        scope: "openid",
        state: "x",
      }
      # Doorkeeper returns 400 (not a redirect) for missing required PKCE
      # parameters because the request itself is malformed. e621's
      # ApplicationController#rescue_exception renders our themed error page
      # rather than doorkeeper's raw error JSON, so we only assert status.
      expect(response).to have_http_status(:bad_request)
    end

    it "accepts authorize with code_challenge S256" do
      verifier  = SecureRandom.urlsafe_base64(64).delete("=")[0, 64]
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      get "/oauth/authorize", params: {
        response_type: "code",
        client_id: public_app.uid,
        redirect_uri: redirect,
        scope: "openid",
        state: "x",
        code_challenge: challenge,
        code_challenge_method: "S256",
      }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /oauth/userinfo with a revoked token" do
    let(:user) { create(:user) }
    let(:owner) { create(:user) }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "rev-client", redirect_uri: "http://localhost/cb",
        scopes: "openid full", confidential: true, owner: owner
      )
    end
    let(:token) { Doorkeeper::AccessToken.create!(application: oauth_app, resource_owner_id: user.id, scopes: "openid full") }

    it "returns 401" do
      token.revoke
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token.token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "refresh token idle expiry" do
    let(:user) { create(:user) }
    let(:owner) { create(:user) }
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "refresh-client", redirect_uri: "http://localhost/cb",
        scopes: "openid full", confidential: true, owner: owner
      )
    end
    let(:token) do
      Doorkeeper::AccessToken.create!(
        application: oauth_app, resource_owner_id: user.id,
        scopes: "openid full", use_refresh_token: true
      )
    end

    def refresh
      post "/oauth/token", params: {
        grant_type: "refresh_token",
        refresh_token: token.refresh_token,
        client_id: oauth_app.uid,
        client_secret: oauth_app.plaintext_secret,
      }
    end

    it "exchanges a refresh token last used within the idle window" do
      token.update_column(:created_at, 29.days.ago)
      refresh
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["refresh_token"]).to be_present
    end

    it "rejects a refresh token idle past the window" do
      token.update_column(:created_at, 31.days.ago)
      refresh
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end
  end
end
