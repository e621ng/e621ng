# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionLoader do
  # ActionDispatch::TestRequest has no session store by default; inject one so
  # SessionLoader can read/write session[:user_id] without DisabledSessionError.
  subject(:loader) { described_class.new(request) }

  # API credentials are only accepted on API formats (E6SEC-519); session/bearer paths ignore this.
  let(:env)     { Rack::MockRequest.env_for("/", "HTTP_ACCEPT" => "application/json").merge("rack.session" => ActionController::TestSession.new) }
  let(:request) { ActionDispatch::TestRequest.create(env) }

  around do |example|
    example.run
  ensure
    CurrentUser.user         = nil
    CurrentUser.api_key      = nil
    CurrentUser.oauth_token  = nil
    CurrentUser.user_session = nil
    CurrentUser.ip_addr      = nil
    CurrentUser.safe_mode    = nil
  end

  describe ".session_token_valid?" do
    let(:user) { create(:user) }
    let(:record) { create(:user_session, user: user, secret: "s3cret") }

    it "is true for a matching token and a live row" do
      expect(described_class.session_token_valid?({ ph: user.password_token, sid: record.id, sk: "s3cret" }, user)).to be true
    end

    it "is false when session[:ph] is stale or missing" do
      expect(described_class.session_token_valid?({ ph: 99_999_999, sid: record.id, sk: "s3cret" }, user)).to be false
      expect(described_class.session_token_valid?({}, user)).to be false
    end

    it "is false when the row is revoked, expired, mismatched or belongs to another user" do
      expect(described_class.session_token_valid?({ ph: user.password_token, sid: record.id, sk: "wrong" }, user)).to be false
      expect(described_class.session_token_valid?({ ph: user.password_token, sid: record.id }, user)).to be false
      record.revoke!("user")
      expect(described_class.session_token_valid?({ ph: user.password_token, sid: record.id, sk: "s3cret" }, user)).to be false
      expired = create(:user_session, user: user, secret: "s3cret", expires_at: 1.minute.ago)
      expect(described_class.session_token_valid?({ ph: user.password_token, sid: expired.id, sk: "s3cret" }, user)).to be false
      foreign = create(:user_session, secret: "s3cret")
      expect(described_class.session_token_valid?({ ph: user.password_token, sid: foreign.id, sk: "s3cret" }, user)).to be false
    end

    context "with a pre-rollout session (no sid)" do
      let(:legacy) { { ph: user.password_token, user_id: user.id, last_authenticated_at: "2026-11-01 00:00:00 UTC" } }

      it "is accepted while legacy sessions are accepted" do
        expect(described_class.session_token_valid?(legacy, user)).to be true
      end

      it "is rejected once an adopted row for the same cookie is no longer active" do
        create(:revoked_user_session, user: user, legacy_key: described_class.legacy_session_key(legacy))
        expect(described_class.session_token_valid?(legacy, user)).to be false
      end

      it "is rejected once legacy sessions are no longer accepted" do
        allow(Danbooru.config.custom_configuration).to receive(:accept_legacy_sessions?).and_return(false)
        expect(described_class.session_token_valid?(legacy, user)).to be false
      end
    end
  end

  describe ".recently_authenticated?" do
    it "is true within the reauth window" do
      expect(described_class.recently_authenticated?({ last_authenticated_at: 5.minutes.ago.utc.to_s })).to be true
    end

    it "is false outside the window, when missing, or when unparseable" do
      expect(described_class.recently_authenticated?({ last_authenticated_at: 2.hours.ago.utc.to_s })).to be false
      expect(described_class.recently_authenticated?({})).to be false
      expect(described_class.recently_authenticated?({ last_authenticated_at: "not a time" })).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #has_api_authentication?
  # ---------------------------------------------------------------------------
  describe "#has_api_authentication?" do
    it "returns false with no credentials" do
      expect(loader.has_api_authentication?).to be false
    end

    it "returns true when HTTP_AUTHORIZATION header is present" do
      env["HTTP_AUTHORIZATION"] = "Basic dXNlcjprZXk="
      expect(loader.has_api_authentication?).to be true
    end

    it "returns true when both login and api_key params are present" do
      env["QUERY_STRING"] = "login=user&api_key=key"
      expect(loader.has_api_authentication?).to be true
    end

    it "returns false with only a login param" do
      env["QUERY_STRING"] = "login=user"
      expect(loader.has_api_authentication?).to be false
    end

    it "returns false with only an api_key param" do
      env["QUERY_STRING"] = "api_key=key"
      expect(loader.has_api_authentication?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #has_header_authentication?
  # ---------------------------------------------------------------------------
  describe "#has_header_authentication?" do
    it "returns false with no credentials" do
      expect(loader.has_header_authentication?).to be false
    end

    it "returns true with a Basic Authorization header" do
      env["HTTP_AUTHORIZATION"] = "Basic dXNlcjprZXk="
      expect(loader.has_header_authentication?).to be true
    end

    it "returns true with a Bearer Authorization header" do
      env["HTTP_AUTHORIZATION"] = "Bearer sometoken"
      expect(loader.has_header_authentication?).to be true
    end

    it "returns false when credentials are only in params" do
      env["QUERY_STRING"] = "login=user&api_key=key"
      expect(loader.has_header_authentication?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #has_login_param_authentication?
  # ---------------------------------------------------------------------------
  describe "#has_login_param_authentication?" do
    it "returns true when both login and api_key params are present" do
      env["QUERY_STRING"] = "login=user&api_key=key"
      expect(loader.has_login_param_authentication?).to be true
    end

    it "returns false with only a login param" do
      env["QUERY_STRING"] = "login=user"
      expect(loader.has_login_param_authentication?).to be false
    end

    it "returns false when credentials are only in an Authorization header" do
      env["HTTP_AUTHORIZATION"] = "Basic dXNlcjprZXk="
      expect(loader.has_login_param_authentication?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #same_origin_request?
  # ---------------------------------------------------------------------------
  describe "#same_origin_request?" do
    it "returns true when no Origin header is present (non-browser client)" do
      expect(loader.same_origin_request?).to be true
    end

    it "returns true when the Origin matches the request's own origin" do
      env["HTTP_ORIGIN"] = request.base_url
      expect(loader.same_origin_request?).to be true
    end

    it "returns false when the Origin is cross-site (forged browser submission)" do
      env["HTTP_ORIGIN"] = "https://attacker.example"
      expect(loader.same_origin_request?).to be false
    end

    it "returns false for an opaque-origin context (literal `Origin: null`)" do
      # Browsers serialize an opaque origin (file://, sandboxed iframe, data: URL) as the
      # literal header value "null", which arrives as the string "null", not nil.
      env["HTTP_ORIGIN"] = "null"
      expect(loader.same_origin_request?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #has_remember_token?
  # ---------------------------------------------------------------------------
  describe "#has_remember_token?" do
    it "returns false when no remember cookie is set" do
      expect(loader.has_remember_token?).to be false
    end

    context "when the remember cookie is present" do
      let(:cookie_jar) do
        instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
          allow(jar).to receive(:encrypted).and_return({ remember: "some_token" })
        end
      end

      before { allow(request).to receive(:cookie_jar).and_return(cookie_jar) }

      it "returns true" do
        expect(loader.has_remember_token?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load — anonymous fallback
  # ---------------------------------------------------------------------------
  describe "#load anonymous fallback" do
    it "sets CurrentUser.ip_addr to the request remote_ip" do
      loader.load
      expect(CurrentUser.ip_addr).to eq(request.remote_ip)
    end

    it "sets CurrentUser.user to User.anonymous when no credentials are present" do
      loader.load
      expect(CurrentUser.user.is_logged_out?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # #load — session authentication
  # ---------------------------------------------------------------------------
  describe "#load session authentication" do
    let(:user) { create(:user) }

    context "with valid session[:user_id] and matching session[:ph]" do
      before do
        request.session[:user_id] = user.id
        request.session[:ph] = user.password_token
      end

      it "sets CurrentUser.user to the session user" do
        loader.load
        expect(CurrentUser.user).to eq(user)
      end

      it "sets CurrentUser.api_key to nil" do
        loader.load
        expect(CurrentUser.api_key).to be_nil
      end
    end

    context "when session[:ph] does not match the user's password_token" do
      before do
        request.session[:user_id] = user.id
        request.session[:ph] = 99_999_999
      end

      it "leaves CurrentUser as anonymous and forgets the login" do
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(request.session[:user_id]).to be_nil
      end
    end

    context "when session[:user_id] refers to a non-existent user" do
      before { request.session[:user_id] = 999_999 }

      it "raises SessionInvalid" do
        expect { loader.load }.to raise_error(SessionLoader::SessionInvalid)
      end
    end

    context "with a session row" do
      let(:cookie_jar) do
        instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
          allow(jar).to receive_messages(encrypted: encrypted_jar, "[]": nil)
        end
      end
      let(:encrypted_jar) { {} }
      let(:record) { create(:remembered_user_session, user: user, secret: "s3cret", created_at: 1.day.ago, last_seen_at: 1.day.ago) }

      before do
        allow(request).to receive(:cookie_jar).and_return(cookie_jar)
        request.session[:user_id] = user.id
        request.session[:ph] = user.password_token
        request.session[:sid] = record.id
        request.session[:sk] = "s3cret"
        Cache.redis.del("user_session_touch:#{record.id}")
      end

      after { Cache.redis.del("user_session_touch:#{record.id}") }

      it "logs the user in and exposes the row" do
        loader.load
        expect(CurrentUser.user).to eq(user)
        expect(CurrentUser.user_session).to eq(record)
      end

      it "records activity once per interval and extends the remember cookie" do
        loader.load
        expect(record.reload.last_seen_at).to be_within(5.seconds).of(Time.now)
        expect(record.expires_at).to be_within(5.seconds).of(Time.now + UserSession::REMEMBER_TIMEOUT)
        expect(encrypted_jar.dig(:remember_session, :value)).to be_present

        record.update_columns(last_seen_at: 1.hour.ago)
        encrypted_jar.delete(:remember_session)
        described_class.new(request).load
        expect(record.reload.last_seen_at).to be_within(5.seconds).of(1.hour.ago)
        expect(encrypted_jar).not_to have_key(:remember_session)
      end

      it "forgets a revoked login instead of serving it" do
        record.revoke!("user")
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(request.session[:user_id]).to be_nil
        expect(request.session[:sid]).to be_nil
        expect(cookie_jar).to have_received(:delete).with(:remember_session)
        expect(cookie_jar).to have_received(:delete).with(:remember)
      end

      it "forgets an expired login" do
        record.update_columns(expires_at: 1.minute.ago)
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(request.session[:sid]).to be_nil
      end
    end

    context "with a pre-rollout session (no sid)" do
      let(:cookie_jar) do
        instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
          allow(jar).to receive_messages(encrypted: encrypted_jar, "[]": nil)
        end
      end
      let(:encrypted_jar) { {} }

      before do
        allow(request).to receive(:cookie_jar).and_return(cookie_jar)
        request.session[:user_id] = user.id
        request.session[:ph] = user.password_token
        request.session[:last_authenticated_at] = 5.minutes.ago.utc.to_s
      end

      it "adopts it into a row and writes sid/sk into the session" do
        expect { loader.load }.to change(UserSession, :count).by(1)
        expect(CurrentUser.user).to eq(user)
        record = UserSession.last
        expect(record).not_to be_touched
        expect(request.session[:sid]).to eq(record.id)
        expect(UserSession.authenticate(request.session[:sid], request.session[:sk])).to eq(record)
        expect(record.legacy_key).to eq(described_class.legacy_session_key(request.session))
        expect(record.remember).to be false
        expect(encrypted_jar).not_to have_key(:remember_session)
      end

      it "issues the new remember cookie when the old one is present, leaving the old one alone" do
        encrypted_jar[:remember] = "old_cookie"
        loader.load
        record = UserSession.last
        expect(record.remember).to be true
        expect(encrypted_jar.dig(:remember_session, :value)).to be_present
        expect(encrypted_jar[:remember]).to eq("old_cookie")
      end

      it "rejects a copy whose adopted row was revoked" do
        create(:revoked_user_session, user: user, legacy_key: described_class.legacy_session_key(request.session))
        expect { loader.load }.not_to change(UserSession, :count)
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(request.session[:user_id]).to be_nil
      end

      it "rejects it once legacy sessions are no longer accepted" do
        allow(Danbooru.config.custom_configuration).to receive(:accept_legacy_sessions?).and_return(false)
        expect { loader.load }.not_to change(UserSession, :count)
        expect(CurrentUser.user.is_logged_out?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load — API key via params
  # ---------------------------------------------------------------------------
  describe "#load API key via params" do
    let(:user)    { create(:user) }
    let(:api_key) { create(:api_key, user: user) }

    context "with valid login and api_key params" do
      before { env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: api_key.key) }

      it "sets CurrentUser.user" do
        loader.load
        expect(CurrentUser.user).to eq(user)
      end

      it "sets CurrentUser.api_key" do
        loader.load
        expect(CurrentUser.api_key).to eq(api_key)
      end
    end

    context "with a wrong api_key" do
      before { env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: "wrong") }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end

      it "does not raise SessionInvalid" do
        expect { loader.load }.to(raise_error { |e| expect(e).not_to be_a(SessionLoader::SessionInvalid) })
      end
    end

    context "with valid params alongside a remember cookie" do
      let(:cookie_jar) do
        instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
          allow(jar).to receive_messages(encrypted: encrypted_jar, "[]": nil)
        end
      end
      let(:encrypted_jar) { { remember: "victim_token" } }

      before do
        # Must precede the stub below, which builds the request.
        env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: api_key.key)
        allow(request).to receive(:cookie_jar).and_return(cookie_jar)
      end

      it "does not rewrite the remember cookie" do
        loader.load
        expect(CurrentUser.user).to eq(user)
        expect(encrypted_jar[:remember]).to eq("victim_token")
      end
    end

    context "with an expired api_key" do
      let(:api_key) { create(:expired_api_key, user: user) }

      before { env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: api_key.key) }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end
    end

    # FIXME: Rack raises ActionController::BadRequest ("Invalid query parameters: Invalid encoding
    # for parameter") for non-UTF-8 query strings before SessionLoader#initialize can rescue it.
    # SessionLoader only rescues ActionDispatch::Http::Parameters::ParseError, not BadRequest.
    # context "with invalid UTF-8 in the login param" do
    #   before { env["QUERY_STRING"] = "login=%FF%FE&api_key=#{api_key.key}" }
    #   it "raises AuthenticationFailure" do
    #     expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
    #   end
    # end

    # FIXME: Same as above — Rack rejects the query string before SessionLoader sees it.
    # context "with invalid UTF-8 in the api_key param" do
    #   before { env["QUERY_STRING"] = "login=#{user.name}&api_key=%FF%FE" }
    #   it "raises AuthenticationFailure" do
    #     expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
    #   end
    # end
  end

  # ---------------------------------------------------------------------------
  # #load — HTTP Basic auth
  # ---------------------------------------------------------------------------
  describe "#load HTTP Basic auth" do
    let(:user)    { create(:user) }
    let(:api_key) { create(:api_key, user: user) }

    def basic_header(login, key)
      "Basic #{Base64.strict_encode64("#{login}:#{key}")}"
    end

    context "with valid credentials in the Authorization header" do
      before { env["HTTP_AUTHORIZATION"] = basic_header(user.name, api_key.key) }

      it "sets CurrentUser.user" do
        loader.load
        expect(CurrentUser.user).to eq(user)
      end

      it "sets CurrentUser.api_key" do
        loader.load
        expect(CurrentUser.api_key).to eq(api_key)
      end
    end

    # FIXME: embedding raw non-UTF-8 bytes (\xFF\xFE) in the HTTP_AUTHORIZATION env key
    # causes request.authorization.present? to raise ArgumentError ("invalid byte sequence
    # in UTF-8") inside has_api_authentication?, before authenticate_basic_auth is reached.
    # has_api_authentication? needs encoding-safe string handling to fix this.
    # context "with invalid Base64 in the Authorization header" do
    #   before { env["HTTP_AUTHORIZATION"] = "Basic \xFF\xFEnot_base64" }
    #   it "raises AuthenticationFailure" do
    #     expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
    #   end
    # end

    context "with invalid UTF-8 in the decoded credentials" do
      before { env["HTTP_AUTHORIZATION"] = "Basic #{Base64.strict_encode64("\xFF\xFE:key")}" }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end
    end

    context "with a wrong API key in the Authorization header" do
      before { env["HTTP_AUTHORIZATION"] = basic_header(user.name, "wrong_key") }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end

      it "does not raise SessionInvalid" do
        expect { loader.load }.to(raise_error { |e| expect(e).not_to be_a(SessionLoader::SessionInvalid) })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load: OAuth bearer token
  # ---------------------------------------------------------------------------
  describe "#load OAuth bearer token" do
    let(:user) { create(:user) }
    let(:app) do
      Doorkeeper::Application.create!(
        name: "test-app",
        redirect_uri: "http://localhost/cb",
        scopes: "openid full",
        confidential: true,
        owner: user,
      )
    end

    def mint_token(scopes)
      Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id, scopes: scopes)
    end

    context "with a valid `full`-scoped token" do
      let(:token) { mint_token("openid full") }

      before { env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}" }

      it "sets CurrentUser.user from the token's resource_owner_id" do
        loader.load
        expect(CurrentUser.user).to eq(user)
      end

      it "clears CurrentUser.api_key" do
        loader.load
        expect(CurrentUser.api_key).to be_nil
      end

      it "marks the request as API-authenticated so CSRF is skipped" do
        expect(loader.has_api_authentication?).to be true
      end
    end

    context "with a token missing the `full` scope" do
      let(:token) { mint_token("openid") }

      before { env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}" }

      it "raises InsufficientScope" do
        expect { loader.load }.to raise_error(SessionLoader::InsufficientScope)
      end
    end

    context "with a revoked token" do
      let(:token) do
        t = mint_token("openid full")
        t.revoke
        t
      end

      before { env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}" }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end
    end

    context "with an expired token" do
      let(:token) { mint_token("openid full").tap { |t| t.update_columns(expires_in: 1, created_at: 1.hour.ago) } }

      before { env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}" }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end
    end

    context "with an unknown bearer token" do
      before { env["HTTP_AUTHORIZATION"] = "Bearer not-a-real-token" }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      end
    end

    context "when the OAuth provider is disabled" do
      let(:token) { mint_token("openid full") }

      before do
        env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}"
        ENV["DANBOORU_ENABLE_OAUTH_PROVIDER"] = "false"
      end

      after { ENV["DANBOORU_ENABLE_OAUTH_PROVIDER"] = "true" }

      it "does not authenticate an otherwise valid token" do
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
      end

      it "does not mark the request as API-authenticated" do
        expect(loader.has_api_authentication?).to be false
      end
    end

    context "with both a bearer header AND login/api_key params" do
      let(:api_key) { create(:api_key, user: user) }
      let(:token)   { mint_token("openid full") }

      before do
        env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}"
        env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: api_key.key)
      end

      it "prefers the bearer token over the api_key" do
        loader.load
        expect(CurrentUser.user).to eq(user)
        expect(CurrentUser.api_key).to be_nil
      end
    end

    context "min-level re-check on bearer use" do
      let(:app) do
        Doorkeeper::Application.create!(
          name: "level-gated", redirect_uri: "http://localhost/cb",
          scopes: "openid full", confidential: true,
          owner: user, minimum_user_level: UserLevel::PRIVILEGED
        )
      end
      let(:token) { Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id, scopes: "openid full") }

      before { env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}" }

      context "when the user still meets the minimum" do
        let(:user) { create(:privileged_user) }

        it "loads normally" do
          loader.load
          expect(CurrentUser.user).to eq(user)
        end
      end

      context "when the user has been demoted below the minimum" do
        let(:user) { create(:user) } # member-level, below privileged

        it "raises LevelBelowMinimum" do
          expect { loader.load }.to raise_error(SessionLoader::LevelBelowMinimum)
        end
      end
    end

    context "auth_time hygiene" do
      let(:user) { create(:user) }
      let(:token) { mint_token("openid full") }

      before do
        env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}"
        user.update_columns(last_logged_in_at: 7.days.ago)
      end

      it "does not bump last_logged_in_at on bearer-only requests" do
        Cache.redis.del("user_login_tracking:user:#{user.id}")
        loader.load
        expect(user.reload.last_logged_in_at).to be < 1.day.ago
      ensure
        Cache.redis.del("user_login_tracking:user:#{user.id}")
      end
    end

    context "refresh-token rotation" do
      let(:old_token) { mint_token("openid full") }
      let(:new_token) do
        Doorkeeper::AccessToken.create!(
          application: app,
          resource_owner_id: user.id,
          scopes: "openid full",
          use_refresh_token: true,
          previous_refresh_token: old_token.refresh_token,
        )
      end

      before do
        old_token.update_columns(refresh_token: "old-refresh-#{SecureRandom.hex(8)}")
        new_token
        env["HTTP_AUTHORIZATION"] = "Bearer #{new_token.token}"
      end

      it "revokes the previous refresh token when the new access token is used" do
        loader.load
        expect(old_token.reload.revoked?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load: remember token
  # ---------------------------------------------------------------------------
  describe "#load remember token" do
    let(:user) { create(:user) }
    let(:verifier) do
      ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
    end
    let(:raw_token) { verifier.generate("#{user.id}:#{user.password_token}", purpose: "rbr", expires_in: 14.days) }
    let(:cookie_jar) do
      instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
        allow(jar).to receive_messages(encrypted: { remember: remember_cookie }, "[]": nil)
      end
    end

    before { allow(request).to receive(:cookie_jar).and_return(cookie_jar) }

    context "with a valid remember token" do
      let(:remember_cookie) { raw_token }

      it "sets CurrentUser.user" do
        loader.load
        expect(CurrentUser.user).to eq(user)
      end

      it "sets session[:user_id]" do
        loader.load
        expect(request.session[:user_id]).to eq(user.id)
      end

      it "sets session[:ph]" do
        loader.load
        expect(request.session[:ph]).to eq(user.password_token)
      end
    end

    context "with a tampered or invalid token" do
      let(:remember_cookie) { "tampered_garbage" }

      it "leaves CurrentUser as anonymous without raising" do
        expect { loader.load }.not_to raise_error
        expect(CurrentUser.user.is_logged_out?).to be true
      end
    end

    context "when the token's password_token does not match the user's current value" do
      let(:remember_cookie) { verifier.generate("#{user.id}:99999999", purpose: "rbr", expires_in: 14.days) }

      it "leaves CurrentUser as anonymous" do
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
      end
    end

    context "with a pre-rollout remember cookie" do
      let(:remember_cookie) { raw_token }
      let(:encrypted_jar) { { remember: remember_cookie } }
      let(:cookie_jar) do
        instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
          allow(jar).to receive_messages(encrypted: encrypted_jar, "[]": nil)
        end
      end

      it "adopts it into a remembered row and issues the new cookie" do
        expect { loader.load }.to change(UserSession, :count).by(1)
        record = UserSession.last
        expect(CurrentUser.user_session).to eq(record)
        expect(record).not_to be_touched
        expect(record.remember).to be true
        expect(record.legacy_key).to eq(described_class.legacy_remember_key(user.id, user.password_token))
        expect(request.session[:sid]).to eq(record.id)
        expect(request.session[:last_authenticated_at]).to be_nil
        expect(encrypted_jar.dig(:remember_session, :value)).to be_present
        expect(encrypted_jar[:remember]).to eq(raw_token)
      end

      it "rejects a copy whose adopted row was revoked and drops the cookie" do
        create(:revoked_user_session, user: user, legacy_key: described_class.legacy_remember_key(user.id, user.password_token))
        expect { loader.load }.not_to change(UserSession, :count)
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(cookie_jar).to have_received(:delete).with(:remember)
      end

      it "drops it once legacy sessions are no longer accepted" do
        allow(Danbooru.config.custom_configuration).to receive(:accept_legacy_sessions?).and_return(false)
        expect { loader.load }.not_to change(UserSession, :count)
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(cookie_jar).to have_received(:delete).with(:remember)
      end
    end

    context "with a remember_session cookie" do
      let(:record) { create(:remembered_user_session, user: user, secret: "s3cret") }
      let(:remember_cookie) { nil }
      let(:encrypted_jar) { { remember_session: verifier.generate("#{record.id}:s3cret", purpose: "rbs", expires_in: 14.days) } }
      let(:cookie_jar) do
        instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
          allow(jar).to receive_messages(encrypted: encrypted_jar, "[]": nil)
        end
      end

      it "restores the login into the session without a reauth timestamp" do
        loader.load
        expect(CurrentUser.user).to eq(user)
        expect(CurrentUser.user_session).to eq(record)
        expect(request.session[:user_id]).to eq(user.id)
        expect(request.session[:ph]).to eq(user.password_token)
        expect(request.session[:sid]).to eq(record.id)
        expect(request.session[:sk]).to eq("s3cret")
        expect(request.session[:last_authenticated_at]).to be_nil
      end

      it "is preferred over an old remember cookie" do
        encrypted_jar[:remember] = raw_token
        expect { loader.load }.not_to change(UserSession, :count)
        expect(CurrentUser.user_session).to eq(record)
      end

      it "forgets a revoked row and drops both cookies" do
        record.revoke!("user")
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
        expect(cookie_jar).to have_received(:delete).with(:remember_session)
        expect(cookie_jar).to have_received(:delete).with(:remember)
      end

      it "ignores a tampered cookie" do
        encrypted_jar[:remember_session] = "garbage"
        expect { loader.load }.not_to raise_error
        expect(CurrentUser.user.is_logged_out?).to be true
      end

      it "ignores a wrong secret" do
        encrypted_jar[:remember_session] = verifier.generate("#{record.id}:wrong", purpose: "rbs", expires_in: 14.days)
        loader.load
        expect(CurrentUser.user.is_logged_out?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load — browser-planted API credentials (E6SEC-519)
  # ---------------------------------------------------------------------------
  describe "#load API credentials from a browser" do
    let(:user)    { create(:user) }
    let(:api_key) { create(:api_key, user: user) }

    before { env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: api_key.key) }

    it "rejects param auth on an HTML request" do
      env["HTTP_ACCEPT"] = "text/html"
      expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure, /only accepted/)
    end

    it "rejects Basic auth on an HTML request" do
      env["QUERY_STRING"] = ""
      env["HTTP_ACCEPT"] = "text/html"
      env["HTTP_AUTHORIZATION"] = "Basic #{Base64.strict_encode64("#{user.name}:#{api_key.key}")}"
      expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure, /only accepted/)
    end

    it "rejects a top-level navigation to a JSON URL" do
      env["HTTP_SEC_FETCH_MODE"] = "navigate"
      env["HTTP_SEC_FETCH_DEST"] = "document"
      expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
    end

    it "rejects a subresource load such as <img>" do
      env["HTTP_SEC_FETCH_MODE"] = "no-cors"
      env["HTTP_SEC_FETCH_DEST"] = "image"
      expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
    end

    it "does not record the IP of a rejected request" do
      env["HTTP_ACCEPT"] = "text/html"
      allow(UserIpTracker).to receive(:track!)
      expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
      expect(UserIpTracker).not_to have_received(:track!)
    end

    it "accepts fetch() from the same origin" do
      env["HTTP_SEC_FETCH_MODE"] = "cors"
      env["HTTP_SEC_FETCH_DEST"] = "empty"
      env["HTTP_SEC_FETCH_SITE"] = "same-origin"
      loader.load
      expect(CurrentUser.user).to eq(user)
    end

    it "accepts the .json path format" do
      env["HTTP_ACCEPT"] = "text/html"
      env["action_dispatch.request.path_parameters"] = { format: "json" }
      loader.load
      expect(CurrentUser.user).to eq(user)
    end

    it "still accepts a bearer token on an HTML request" do
      env["QUERY_STRING"] = ""
      env["HTTP_ACCEPT"] = "text/html"
      app = Doorkeeper::Application.create!(name: "test-app", redirect_uri: "http://localhost/cb", scopes: "full", confidential: true, owner: user)
      token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id, scopes: "full")
      env["HTTP_AUTHORIZATION"] = "Bearer #{token.token}"
      loader.load
      expect(CurrentUser.user).to eq(user)
    end

    describe "IP attribution" do
      before do
        Cache.redis.del("user_login_tracking:api_key:#{api_key.id}")
        user.update_columns(last_ip_addr: "10.0.0.1")
        allow(UserIpTracker).to receive(:track!)
        env["HTTP_SEC_FETCH_MODE"] = "cors"
        env["HTTP_SEC_FETCH_DEST"] = "empty"
      end

      after { Cache.redis.del("user_login_tracking:api_key:#{api_key.id}") }

      %w[cross-site same-site].each do |site|
        it "skips IP tracking for a #{site} request" do
          env["HTTP_SEC_FETCH_SITE"] = site
          loader.load
          expect(UserIpTracker).not_to have_received(:track!)
          expect(user.reload.last_ip_addr.to_s).to eq("10.0.0.1")
          expect(api_key.reload.last_used_at).to be_present
        end
      end

      it "tracks the IP for a same-origin request" do
        env["HTTP_SEC_FETCH_SITE"] = "same-origin"
        loader.load
        expect(UserIpTracker).to have_received(:track!).with(user, request.remote_ip)
        expect(user.reload.last_ip_addr.to_s).to eq(request.remote_ip)
      end

      it "tracks the IP for a non-browser client" do
        %w[HTTP_SEC_FETCH_MODE HTTP_SEC_FETCH_DEST].each { |k| env.delete(k) }
        loader.load
        expect(UserIpTracker).to have_received(:track!).with(user, request.remote_ip)
      end

      it "tracks a cross-site request authenticated by the session cookie" do
        env["QUERY_STRING"] = ""
        env["HTTP_SEC_FETCH_SITE"] = "cross-site"
        request.session[:user_id] = user.id
        request.session[:ph] = user.password_token
        loader.load
        expect(UserIpTracker).to have_received(:track!).with(user, request.remote_ip)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load — ban enforcement
  # ---------------------------------------------------------------------------
  describe "#load ban enforcement" do
    # Ban callbacks (create_feedback, create_ban_mod_action) write records that need
    # a CurrentUser; include_context supplies one for the duration of each example.
    include_context "as admin"

    let(:user)    { create(:banned_user) }
    let(:api_key) { create(:api_key, user: user) }

    before { env["QUERY_STRING"] = Rack::Utils.build_query(login: user.name, api_key: api_key.key) }

    context "with a permanent ban (no ban record)" do
      it "raises AuthenticationFailure mentioning 'forever'" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure, /forever/)
      end
    end

    context "with a time-limited ban" do
      before { create(:ban, user: user, duration: 7, prevent_login: true) }

      it "raises AuthenticationFailure mentioning the suspension" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure, /suspended/)
      end
    end

    context "with an expired ban" do
      let!(:ban) { create(:ban, user: user, duration: 7, prevent_login: true) }

      before { ban.update_columns(expires_at: 2.days.ago) }

      it "unbans the user and does not raise" do
        expect { loader.load }.not_to raise_error
        expect(user.reload.is_restricted?).to be false
      end
    end

    context "with a soft ban (prevent_login: false)" do
      before { create(:ban, user: user, duration: 7, prevent_login: false) }

      it "does not raise AuthenticationFailure" do
        expect { loader.load }.not_to raise_error
      end
    end

    context "when the banned user authenticates via API key" do
      it "does not raise SessionInvalid" do
        expect { loader.load }.to(raise_error { |e| expect(e).not_to be_a(SessionLoader::SessionInvalid) })
      end
    end

    context "when the banned user authenticates via session" do
      before do
        env["QUERY_STRING"] = ""
        request.session[:user_id] = user.id
        request.session[:ph] = user.password_token
      end

      it "raises SessionInvalid" do
        expect { loader.load }.to raise_error(SessionLoader::SessionInvalid, /forever/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load — safe mode
  # ---------------------------------------------------------------------------
  describe "#load safe mode" do
    # set_safe_mode is independent of auth state; test via anonymous requests to
    # avoid session-before-env-mutation timing issues.

    it "is false by default" do
      loader.load
      expect(CurrentUser.safe_mode?).to be false
    end

    it "is true when the safe_mode param is truthy" do
      # env must be modified before request is first accessed (TestRequest copies env)
      env["QUERY_STRING"] = "safe_mode=1"
      loader.load
      expect(CurrentUser.safe_mode?).to be true
    end

    it "is true when Danbooru.config.safe_mode? returns true" do
      allow(Danbooru.config.custom_configuration).to receive(:safe_mode?).and_return(true)
      loader.load
      expect(CurrentUser.safe_mode?).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # #load — login tracking
  # ---------------------------------------------------------------------------
  describe "#load login tracking" do
    let(:user)    { create(:user) }
    let(:api_key) { create(:api_key, user: user) }

    before do
      request.session[:user_id] = user.id
      request.session[:ph] = user.password_token
    end

    it "updates last_logged_in_at when stale" do
      user.update_columns(last_logged_in_at: 2.days.ago)
      loader.load
      expect(user.reload.last_logged_in_at).to be > 1.minute.ago
    end

    it "updates last_ip_addr when the request IP differs" do
      user.update_columns(last_ip_addr: "10.0.0.1")
      loader.load
      expect(user.reload.last_ip_addr).to eq(request.remote_ip)
    end

    context "within the cache window" do
      let(:cache_key) { "user_login_tracking:user:#{user.id}" }

      before do
        user.update_columns(last_logged_in_at: 2.days.ago)
        Cache.redis.setex(cache_key, 60, "1")
      end

      after { Cache.redis.del(cache_key) }

      it "does not update last_logged_in_at" do
        loader.load
        expect(user.reload.last_logged_in_at).to be < 1.minute.ago
      end
    end

    context "when authenticated via API key" do
      # Override env so API key params are present when TestRequest is created.
      # The outer before block (session setup) still runs but API auth takes priority.
      let(:env) do
        { "rack.session" => ActionController::TestSession.new,
          "HTTP_ACCEPT" => "application/json",
          "QUERY_STRING" => Rack::Utils.build_query(login: user.name, api_key: api_key.key), }
      end

      # Clear the Redis login-tracking key before and after: if DB IDs reset between
      # test files (truncation-based cleanup), a stale key from a prior run can match
      # this api_key's ID and cause update_user_login_tracking to skip update_usage!.
      before { Cache.redis.del("user_login_tracking:api_key:#{api_key.id}") }
      after  { Cache.redis.del("user_login_tracking:api_key:#{api_key.id}") }

      it "updates api_key.last_used_at" do
        loader.load
        expect(api_key.reload.last_used_at).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #load — dmail cookie refresh
  # ---------------------------------------------------------------------------
  describe "#load dmail cookie refresh" do
    let(:user) { create(:user) }
    let(:cookie_jar) do
      instance_spy(ActionDispatch::Cookies::CookieJar).tap do |jar|
        allow(jar).to receive(:encrypted).and_return({ remember: nil })
        allow(jar).to receive(:[]).with(:hide_dmail_notice).and_return(dmail_cookie_value)
      end
    end

    before do
      allow(request).to receive(:cookie_jar).and_return(cookie_jar)
      request.session[:user_id] = user.id
      request.session[:ph] = user.password_token
    end

    # user has no dmails, so has_mail? == false and has_mail?.to_s == "1"
    context "when the user has no mail, but cookie value is '1'" do
      let(:dmail_cookie_value) { "1" }

      it "deletes the :hide_dmail_notice cookie" do
        loader.load
        expect(cookie_jar).to have_received(:delete).with(:hide_dmail_notice)
      end
    end

    context "when the user has no mail, and cookie value is '0'" do
      let(:dmail_cookie_value) { "0" }

      it "does not delete the :hide_dmail_notice cookie" do
        loader.load
        expect(cookie_jar).not_to have_received(:delete).with(:hide_dmail_notice)
      end
    end

    context "when the user has mail, and cookie value is '1'" do
      let(:dmail_cookie_value) { "1" }

      it "does not delete the :hide_dmail_notice cookie" do
        CurrentUser.scoped(create(:user)) do
          create(:dmail, to: user)
        end
        loader.load
        expect(cookie_jar).not_to have_received(:delete).with(:hide_dmail_notice)
      end
    end

    context "for an anonymous user" do
      let(:dmail_cookie_value) { "1" }

      before do
        request.session.delete(:user_id)
        request.session.delete(:ph)
      end

      it "does not delete the :hide_dmail_notice cookie" do
        loader.load
        expect(cookie_jar).not_to have_received(:delete).with(:hide_dmail_notice)
      end
    end
  end
end
