# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionsController do
  include_context "as admin"

  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /session/new
  # ---------------------------------------------------------------------------

  describe "GET /session/new" do
    it "returns 200" do
      get new_session_path
      expect(response).to have_http_status(:ok)
    end

    context "when turnstile is enabled" do
      before do
        allow(Danbooru.config.custom_configuration).to receive_messages(
          enable_turnstile?: true,
          turnstile_site_key: "test-site-key",
        )
      end

      it "renders the widget and its nonced script when a captcha is required" do
        get new_session_path(captcha: 1)
        expect(response.body).to include('class="cf-turnstile" data-sitekey="test-site-key"')
        expect(response.body).to match(%r{<script[^>]+src="https://challenges\.cloudflare\.com/turnstile/v0/api\.js"[^>]+nonce=})
      end

      it "does not render the widget by default" do
        get new_session_path
        expect(response.body).not_to include("cf-turnstile")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /session
  # ---------------------------------------------------------------------------

  describe "POST /session" do
    let(:ip_limiter) { instance_double(RateLimiter, throttled?: false, hit!: 1) }
    let(:account_limiter) { instance_double(RateLimiter, throttled?: false, hit!: 1, reset!: nil) }

    before do
      allow(RateLimiter).to receive(:new).and_return(ip_limiter)
      allow(RateLimiter).to receive(:new).with(a_string_starting_with("login:account:"), any_args).and_return(account_limiter)
    end

    context "when rate limited by IP" do
      before { allow(ip_limiter).to receive(:throttled?).and_return(true) }

      it "redirects to new_session_path with a notice (HTML)" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to match(/Too many login attempts/)
      end

      it "returns 429 with an error message (JSON)" do
        post session_path(format: :json), params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body["error"]).to match(/Too many login attempts/)
      end
    end

    context "when rate limited by account" do
      before { allow(account_limiter).to receive(:throttled?).and_return(true) }

      context "with turnstile disabled" do
        before { allow(Danbooru.config.custom_configuration).to receive(:enable_turnstile?).and_return(false) }

        it "redirects to new_session_path with a notice (HTML)" do
          post session_path, params: { session: { name: member.name, password: "hexerade" } }
          expect(response).to redirect_to(new_session_path)
          expect(flash[:notice]).to match(/Too many failed login attempts/)
          expect(session[:user_id]).to be_nil
          expect(account_limiter).not_to have_received(:hit!)
        end

        it "returns 429 without a captcha code (JSON)" do
          post session_path(format: :json), params: { session: { name: member.name, password: "hexerade" } }
          expect(response).to have_http_status(:too_many_requests)
          expect(response.parsed_body["error"]).to match(/Too many failed login attempts/)
          expect(response.parsed_body["code"]).to be_nil
        end
      end

      context "with turnstile enabled" do
        before do
          allow(Danbooru.config.custom_configuration).to receive(:enable_turnstile?).and_return(true)
          allow(TurnstileVerifier).to receive(:verify).and_return(false)
        end

        it "redirects to the captcha page, keeping the url param (HTML)" do
          post session_path, params: { "session": { name: member.name, password: "hexerade", url: "/artists" }, "cf-turnstile-response": "turnstile-token" }
          expect(response).to redirect_to(new_session_path(url: "/artists", captcha: 1))
          expect(flash[:notice]).to match(/complete the captcha/)
          expect(TurnstileVerifier).to have_received(:verify).with("turnstile-token", "127.0.0.1")
          expect(session[:user_id]).to be_nil
        end

        it "returns 429 with captcha_required and the full-page url (JSON)" do
          post session_path(format: :json), params: { session: { name: member.name, password: "hexerade" } }
          expect(response).to have_http_status(:too_many_requests)
          expect(response.parsed_body["code"]).to eq("captcha_required")
          expect(response.parsed_body["url"]).to eq(new_session_path(captcha: 1))
        end

        it "logs in when the captcha is solved" do
          allow(TurnstileVerifier).to receive(:verify).and_return(true)
          post session_path, params: { "session": { name: member.name, password: "hexerade" }, "cf-turnstile-response": "turnstile-token" }
          expect(response).to redirect_to(posts_path)
          expect(session[:user_id]).to eq(member.id)
          expect(account_limiter).to have_received(:reset!)
        end

        it "still rejects wrong credentials after a solved captcha and counts the failure" do
          allow(TurnstileVerifier).to receive(:verify).and_return(true)
          post session_path, params: { "session": { name: member.name, password: "wrong_password" }, "cf-turnstile-response": "turnstile-token" }
          expect(response).to redirect_to(new_session_path)
          expect(flash[:notice]).to match(/incorrect/i)
          expect(account_limiter).to have_received(:hit!)
        end
      end

      context "from an IP the account has used before" do
        before { allow(TurnstileVerifier).to receive(:verify) }

        it "skips the account limiter for a tracked IP" do
          create(:user_ip_address, user: member, ip_addr: "127.0.0.1")
          post session_path, params: { session: { name: member.name, password: "hexerade" } }
          expect(response).to redirect_to(posts_path)
          expect(session[:user_id]).to eq(member.id)
          expect(TurnstileVerifier).not_to have_received(:verify)
        end

        it "skips the account limiter for the last login IP" do
          member.update_columns(last_ip_addr: "127.0.0.1")
          post session_path, params: { session: { name: member.name, password: "hexerade" } }
          expect(response).to redirect_to(posts_path)
          expect(session[:user_id]).to eq(member.id)
        end

        it "does not skip it for an unknown account" do
          allow(Danbooru.config.custom_configuration).to receive(:enable_turnstile?).and_return(false)
          post session_path, params: { session: { name: "nobody_here", password: "hexerade" } }
          expect(response).to redirect_to(new_session_path)
          expect(flash[:notice]).to match(/Too many failed login attempts/)
        end
      end
    end

    context "with a name no account can have" do
      it "does not construct an account limiter for a blank name" do
        post session_path, params: { session: { name: "", password: "hexerade" } }
        expect(RateLimiter).not_to have_received(:new).with(a_string_starting_with("login:account:"), any_args)
        expect(response).to redirect_to(new_session_path)
      end

      it "does not construct an account limiter for an overlong name" do
        post session_path, params: { session: { name: "x" * 21, password: "hexerade" } }
        expect(RateLimiter).not_to have_received(:new).with(a_string_starting_with("login:account:"), any_args)
        expect(ip_limiter).to have_received(:hit!)
      end
    end

    context "with valid credentials" do
      it "redirects to posts_path (HTML)" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to redirect_to(posts_path)
      end

      it "redirects to a safe url param" do
        post session_path, params: { session: { name: member.name, password: "hexerade", url: "/artists" } }
        expect(response).to redirect_to("/artists")
      end

      it "ignores a url param starting with //" do
        post session_path, params: { session: { name: member.name, password: "hexerade", url: "//evil.example.com" } }
        expect(response).to redirect_to(posts_path)
      end

      it "ignores a url param that does not start with /" do
        post session_path, params: { session: { name: member.name, password: "hexerade", url: "https://evil.example.com" } }
        expect(response).to redirect_to(posts_path)
      end

      it "returns 200 with a url key (JSON)" do
        post session_path(format: :json), params: { session: { name: member.name, password: "hexerade" } }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["url"]).to eq(posts_path)
      end

      it "sets session[:user_id] to the authenticated user" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(session[:user_id]).to eq(member.id)
      end

      it "resets the account limiter" do
        post session_path, params: { session: { name: member.name, password: "hexerade" } }
        expect(account_limiter).to have_received(:reset!)
        expect(account_limiter).not_to have_received(:hit!)
      end
    end

    context "with invalid credentials" do
      it "redirects to new_session_path with a notice (HTML)" do
        post session_path, params: { session: { name: member.name, password: "wrong_password" } }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to match(/incorrect/i)
      end

      it "returns 401 with an error message (JSON)" do
        post session_path(format: :json), params: { session: { name: member.name, password: "wrong_password" } }
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to be_present
      end

      it "counts the failure against both limiters" do
        post session_path, params: { session: { name: member.name.upcase, password: "wrong_password" } }
        expect(ip_limiter).to have_received(:hit!)
        expect(account_limiter).to have_received(:hit!)
        expect(account_limiter).not_to have_received(:reset!)
        expect(RateLimiter).to have_received(:new).with("login:account:#{member.name.downcase}", limit: 20, period: 1.hour)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /session
  # ---------------------------------------------------------------------------

  describe "DELETE /session" do
    before do
      allow(RateLimiter).to receive(:new).and_return(instance_double(RateLimiter, throttled?: false, hit!: 1, reset!: nil))
      make_session(member)
    end

    it "redirects to referer when present" do
      delete session_path, headers: { "Referer" => posts_path }
      expect(response).to redirect_to(posts_path)
    end

    it "redirects to root_path when no referer" do
      delete session_path
      expect(response).to redirect_to(root_path)
    end

    it "does not redirect to an external referer" do
      delete session_path, headers: { "Referer" => "https://evil.example.com" }
      expect(response).to redirect_to(root_path)
    end

    it "clears session[:user_id]" do
      delete session_path
      expect(session[:user_id]).to be_nil
    end

    it "sets a logged-out flash notice" do
      delete session_path
      expect(flash[:notice]).to eq("You are now logged out")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /session/confirm_password
  # ---------------------------------------------------------------------------

  describe "GET /session/confirm_password" do
    it "returns 200" do
      sign_in_as member
      get confirm_password_session_path
      expect(response).to have_http_status(:ok)
    end
  end
end
