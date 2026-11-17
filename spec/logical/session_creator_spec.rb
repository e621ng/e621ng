# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionCreator do
  let(:user) { create(:user) }

  after { CurrentUser.user_session = nil }

  describe "#challenge_user" do
    let(:session) { {} }
    let(:creator) { described_class.new(nil, session, nil, nil, nil) }

    def stash_challenge(user_id)
      session[:totp_user_id] = user_id
      session[:totp_expires_at] = 5.minutes.from_now.utc.to_s
      session[:totp_remember] = false
      session[:totp_url] = "/artists"
    end

    it "returns the challenged user while the challenge is live" do
      stash_challenge(user.id)
      expect(creator.challenge_user).to eq(user)
      expect(session[:totp_user_id]).to eq(user.id)
    end

    it "returns nil without touching the session when no challenge exists" do
      expect(creator.challenge_user).to be_nil
      expect(session).to be_empty
    end

    it "clears the challenge when expired" do
      stash_challenge(user.id)
      session[:totp_expires_at] = 1.minute.ago.utc.to_s
      expect(creator.challenge_user).to be_nil
      expect(session).to be_empty
    end

    it "clears the challenge when the timestamp is missing" do
      stash_challenge(user.id)
      session[:totp_expires_at] = nil
      expect(creator.challenge_user).to be_nil
      expect(session.compact).to be_empty
    end

    it "clears the challenge when the challenged user no longer exists" do
      stash_challenge(-1)
      expect(creator.challenge_user).to be_nil
      expect(session).to be_empty
    end
  end

  describe "#establish" do
    let(:env) { Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "203.0.113.7", "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/132.0").merge("rack.session" => ActionController::TestSession.new) }
    let(:request) { ActionDispatch::TestRequest.create(env) }
    let(:session) { request.session }
    let(:cookie_jar) { instance_spy(ActionDispatch::Cookies::CookieJar, encrypted: {}) }
    let(:remember) { false }
    let(:creator) { described_class.new(request, session, cookie_jar, nil, nil, remember) }

    it "starts a fresh session, mints a row and writes the login keys" do
      session[:planted] = "by an attacker"
      session[:recent_pool_ids] = "3,5"
      record = creator.establish(user)

      expect(session[:planted]).to be_nil
      expect(session[:recent_pool_ids]).to eq("3,5")
      expect(session[:user_id]).to eq(user.id)
      expect(session[:ph]).to eq(user.password_token)
      expect(session[:sid]).to eq(record.id)
      expect(UserSession.authenticate(session[:sid], session[:sk])).to eq(record)
      expect(SessionLoader.recently_authenticated?(session)).to be true
      expect(record.user).to eq(user)
      expect(record.remember).to be false
      expect(CurrentUser.user_session).to eq(record)
      expect(user.reload.last_ip_addr.to_s).to eq("203.0.113.7")
      expect(cookie_jar.encrypted).not_to have_key(:remember_session)
    end

    context "with remember" do
      let(:remember) { true }

      it "issues both remember cookies while legacy sessions are accepted" do
        record = creator.establish(user)
        expect(record.remember).to be true
        sid, secret = SessionCreator.remember_verifier.verify(cookie_jar.encrypted.dig(:remember_session, :value), purpose: "rbs").split(":", 2)
        expect(sid.to_i).to eq(record.id)
        expect(secret).to eq(session[:sk])
        expect(SessionCreator.remember_verifier.verify(cookie_jar.encrypted.dig(:remember, :value), purpose: "rbr")).to eq("#{user.id}:#{user.password_token}")
      end

      it "issues only the new remember cookie once legacy sessions are rejected" do
        allow(Danbooru.config.custom_configuration).to receive(:accept_legacy_sessions?).and_return(false)
        creator.establish(user)
        expect(cookie_jar.encrypted).to have_key(:remember_session)
        expect(cookie_jar.encrypted).not_to have_key(:remember)
      end
    end

    context "when re-confirming the login already in the session" do
      let!(:record) { creator.establish(user) }

      it "keeps the row and only refreshes the timestamp and token" do
        session[:last_authenticated_at] = 3.hours.ago.utc.to_s
        session[:keep_me] = 1

        expect { described_class.new(request, session, cookie_jar, nil, nil).establish(user) }.not_to change(UserSession, :count)
        expect(session[:sid]).to eq(record.id)
        expect(session[:keep_me]).to eq(1)
        expect(SessionLoader.recently_authenticated?(session)).to be true
        expect(record.reload).to be_active
      end

      it "upgrades the row to remembered when asked" do
        described_class.new(request, session, cookie_jar, nil, nil, true).establish(user)
        expect(record.reload.remember).to be true
        expect(cookie_jar.encrypted).to have_key(:remember_session)
      end
    end

    it "revokes the previous row when a different user logs in" do
      first = creator.establish(user)
      other = create(:user)
      second = described_class.new(request, session, cookie_jar, nil, nil).establish(other)

      expect(first.reload.revoked_reason).to eq("logout")
      expect(second).to be_active
      expect(session[:user_id]).to eq(other.id)
      expect(cookie_jar).to have_received(:delete).with(:remember_session).at_least(:once)
    end

    it "mints a new row when the session names a dead row" do
      first = creator.establish(user)
      first.revoke!("user")
      second = described_class.new(request, session, cookie_jar, nil, nil).establish(user)
      expect(second).not_to eq(first)
      expect(session[:sid]).to eq(second.id)
    end
  end

  describe ".clear_login" do
    it "drops the login keys and both remember cookies without touching other keys" do
      session = { user_id: 1, ph: 2, sid: 3, sk: "x", last_authenticated_at: "t", totp_user_id: 5 }
      cookie_jar = instance_spy(ActionDispatch::Cookies::CookieJar)

      described_class.clear_login(session, cookie_jar)

      expect(session).to eq({ totp_user_id: 5 })
      expect(cookie_jar).to have_received(:delete).with(:remember)
      expect(cookie_jar).to have_received(:delete).with(:remember_session).at_least(:once)
    end
  end
end
