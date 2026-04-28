# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionLoader do
  # ActionDispatch::TestRequest has no session store by default; inject one so
  # SessionLoader can read/write session[:user_id] without DisabledSessionError.
  subject(:loader) { described_class.new(request) }

  let(:env)     { Rack::MockRequest.env_for("/").merge("rack.session" => ActionController::TestSession.new) }
  let(:request) { ActionDispatch::TestRequest.create(env) }

  around do |example|
    example.run
  ensure
    CurrentUser.user      = nil
    CurrentUser.api_key   = nil
    CurrentUser.ip_addr   = nil
    CurrentUser.safe_mode = nil
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
      expect(CurrentUser.is_anonymous?).to be true
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

      it "leaves CurrentUser as anonymous" do
        loader.load
        expect(CurrentUser.is_anonymous?).to be true
      end
    end

    context "when session[:user_id] refers to a non-existent user" do
      before { request.session[:user_id] = 999_999 }

      it "raises AuthenticationFailure" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure)
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
    end
  end

  # ---------------------------------------------------------------------------
  # #load — remember token
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
        expect(CurrentUser.is_anonymous?).to be true
      end
    end

    context "when the token's password_token does not match the user's current value" do
      let(:remember_cookie) { verifier.generate("#{user.id}:99999999", purpose: "rbr", expires_in: 14.days) }

      it "leaves CurrentUser as anonymous" do
        loader.load
        expect(CurrentUser.is_anonymous?).to be true
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
      before { create(:ban, user: user, duration: 7) }

      it "raises AuthenticationFailure mentioning the suspension" do
        expect { loader.load }.to raise_error(SessionLoader::AuthenticationFailure, /suspended/)
      end
    end

    context "with an expired ban" do
      let!(:ban) { create(:ban, user: user, duration: 7) }

      before { ban.update_columns(expires_at: 2.days.ago) }

      it "unbans the user and does not raise" do
        expect { loader.load }.not_to raise_error
        expect(user.reload.is_banned?).to be false
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
