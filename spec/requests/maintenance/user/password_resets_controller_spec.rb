# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::PasswordResetsController do
  before { allow(RateLimiter).to receive(:throttle!).and_return(false) }

  describe "GET /maintenance/user/password_reset/new" do
    it "returns 200" do
      get new_maintenance_user_password_reset_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the turnstile widget when enabled" do
      allow(Danbooru.config.custom_configuration).to receive_messages(enable_turnstile?: true, turnstile_site_key: "test-site-key")
      get new_maintenance_user_password_reset_path
      expect(response.body).to include('class="cf-turnstile" data-sitekey="test-site-key"')
    end

    it "does not render the turnstile widget when disabled" do
      get new_maintenance_user_password_reset_path
      expect(response.body).not_to include("cf-turnstile")
    end
  end

  describe "POST /maintenance/user/password_reset" do
    context "when the email matches a regular user" do
      let(:user) { create(:user) }

      it "creates a nonce" do
        expect { post maintenance_user_password_reset_path, params: { email: user.email } }
          .to change(UserPasswordResetNonce, :count).by(1)
      end

      it "redirects with the generic notice" do
        post maintenance_user_password_reset_path, params: { email: user.email }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to include("If your email was on file")
      end

      it "counts the request against the IP and email limiters" do
        post maintenance_user_password_reset_path, params: { email: user.email }
        expect(RateLimiter).to have_received(:throttle!).with("account_recovery:127.0.0.1", limit: 5, period: 1.hour)
        expect(RateLimiter).to have_received(:throttle!).with("account_recovery:email:#{user.email.downcase}", limit: 3, period: 1.hour)
      end

      it "normalizes the email before keying the limiter" do
        post maintenance_user_password_reset_path, params: { email: "  #{user.email.upcase} " }
        expect(RateLimiter).to have_received(:throttle!).with("account_recovery:email:#{user.email.downcase}", limit: 3, period: 1.hour)
      end
    end

    context "when the email matches a moderator" do
      let(:moderator) { create(:moderator_user) }

      it "does not create a nonce" do
        expect { post maintenance_user_password_reset_path, params: { email: moderator.email } }
          .not_to change(UserPasswordResetNonce, :count)
      end

      it "redirects with the same generic notice" do
        post maintenance_user_password_reset_path, params: { email: moderator.email }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email is unknown" do
      it "does not create a nonce" do
        expect { post maintenance_user_password_reset_path, params: { email: "nobody@example.com" } }
          .not_to change(UserPasswordResetNonce, :count)
      end

      it "redirects with the same generic notice" do
        post maintenance_user_password_reset_path, params: { email: "nobody@example.com" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email is blank" do
      it "does not consult the email limiter" do
        post maintenance_user_password_reset_path, params: { email: "" }
        expect(RateLimiter).not_to have_received(:throttle!).with(a_string_starting_with("account_recovery:email:"), any_args)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when rate limited by IP" do
      let(:user) { create(:user) }

      before do
        allow(RateLimiter).to receive(:throttle!).with("account_recovery:127.0.0.1", any_args).and_return(true)
        allow(TurnstileVerifier).to receive(:verify)
      end

      it "redirects with a throttle notice and creates nothing" do
        expect { post maintenance_user_password_reset_path, params: { email: user.email } }
          .not_to change(UserPasswordResetNonce, :count)
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Too many requests. Try again later.")
        expect(TurnstileVerifier).not_to have_received(:verify)
      end
    end

    context "when rate limited by email" do
      let(:user) { create(:user) }

      before do
        allow(RateLimiter).to receive(:throttle!).with(a_string_starting_with("account_recovery:email:"), any_args).and_return(true)
      end

      it "shows the generic notice without creating a nonce" do
        expect { post maintenance_user_password_reset_path, params: { email: user.email } }
          .not_to change(UserPasswordResetNonce, :count)
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when turnstile is enabled" do
      let(:user) { create(:user) }

      before do
        allow(Danbooru.config.custom_configuration).to receive_messages(enable_turnstile?: true, turnstile_site_key: "test-site-key")
      end

      it "rejects the request when verification fails" do
        allow(TurnstileVerifier).to receive(:verify).and_return(false)
        expect { post maintenance_user_password_reset_path, params: { email: user.email } }
          .not_to change(UserPasswordResetNonce, :count)
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Captcha verification failed, please try again")
        expect(RateLimiter).not_to have_received(:throttle!).with(a_string_starting_with("account_recovery:email:"), any_args)
      end

      it "creates a nonce when verification succeeds" do
        allow(TurnstileVerifier).to receive(:verify).and_return(true)
        expect { post maintenance_user_password_reset_path, params: { email: user.email, "cf-turnstile-response" => "turnstile-token" } }
          .to change(UserPasswordResetNonce, :count).by(1)
        expect(TurnstileVerifier).to have_received(:verify).with("turnstile-token", "127.0.0.1")
      end
    end

    context "when turnstile is disabled" do
      let(:user) { create(:user) }

      it "does not verify a captcha" do
        allow(TurnstileVerifier).to receive(:verify)
        expect { post maintenance_user_password_reset_path, params: { email: user.email } }
          .to change(UserPasswordResetNonce, :count).by(1)
        expect(TurnstileVerifier).not_to have_received(:verify)
      end
    end
  end

  describe "GET /maintenance/user/password_reset/edit" do
    context "with a valid nonce" do
      let(:nonce) { create(:user_password_reset_nonce) }

      it "returns 200" do
        get edit_maintenance_user_password_reset_path, params: { uid: nonce.user_id, key: nonce.key }
        expect(response).to have_http_status(:ok)
      end

      it "does not carry the reset key into the sign-in link" do
        get edit_maintenance_user_password_reset_path, params: { uid: nonce.user_id, key: nonce.key }
        sign_in_href = response.parsed_body.at_css("a.auth-login-link")["href"]
        expect(sign_in_href).to include("url=")
        expect(sign_in_href).not_to include(nonce.key)
      end
    end

    context "with an invalid nonce" do
      it "returns 200 and renders the invalid-reset message" do
        get edit_maintenance_user_password_reset_path, params: { uid: "0", key: "doesnotexist" }
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a UID containing trailing non-numeric characters" do
      let(:nonce) { create(:user_password_reset_nonce) }

      it "sanitizes the UID and returns 200" do
        get edit_maintenance_user_password_reset_path,
            params: { uid: "#{nonce.user_id}关闭网页", key: nonce.key }
        expect(response).to have_http_status(:ok)
      end

      it "does not log the reset key" do
        allow(Rails.logger).to receive(:warn).and_call_original
        get edit_maintenance_user_password_reset_path,
            params: { uid: "#{nonce.user_id}关闭网页", key: nonce.key }

        expect(Rails.logger).to have_received(:warn).with(satisfy { |msg| msg.include?("key_present=true") && msg.exclude?(nonce.key) })
      end
    end

    context "with an excessively large UID" do
      it "returns 200 without raising and renders the invalid-reset message" do
        expect do
          get edit_maintenance_user_password_reset_path,
              params: { uid: "212488730429208853042920885", key: "doesnotexist" }
        end.not_to raise_error

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "PATCH /maintenance/user/password_reset" do
    def error_text
      response.parsed_body.at_css(".error-messages").text
    end

    context "with a valid nonce and matching passwords" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "redirects with a success notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "hexerade1234" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Password reset")
      end

      it "changes the user's password" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "hexerade1234" }
        expect(nonce.user.reload.bcrypt_password).to eq("hexerade1234")
      end

      it "destroys the nonce" do
        expect do
          patch maintenance_user_password_reset_path,
                params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "hexerade1234" }
        end.to change(UserPasswordResetNonce, :count).by(-1)
      end

      it "destroys every nonce for the user" do
        create(:user_password_reset_nonce, user: nonce.user)
        expect do
          patch maintenance_user_password_reset_path,
                params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "hexerade1234" }
        end.to change(UserPasswordResetNonce, :count).by(-2)
      end
    end

    context "with mismatched passwords" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "re-renders the form with the error" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "different" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(error_text).to include("doesn't match")
        expect(response.parsed_body.at_css("input[name=key]")["value"]).to eq(nonce.key)
      end

      it "does not destroy the nonce or change the password" do
        expect do
          patch maintenance_user_password_reset_path,
                params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "different" }
        end.not_to change(UserPasswordResetNonce, :count)
        expect(nonce.user.reload.bcrypt_password).to eq("hexerade")
      end
    end

    context "with blank passwords" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "rejects the reset" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "", password_confirm: "" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(error_text).to include("can't be blank")
        expect(nonce.user.reload.bcrypt_password).to eq("hexerade")
      end
    end

    context "with missing password params" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "rejects the reset without raising" do
        expect do
          patch maintenance_user_password_reset_path, params: { uid: nonce.user_id, key: nonce.key }
        end.not_to raise_error
        expect(response).to have_http_status(:unprocessable_content)
        expect(nonce.user.reload.bcrypt_password).to eq("hexerade")
      end
    end

    context "with an insecure password" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "rejects the reset" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "password", password_confirm: "password" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(error_text).to include("insecure")
      end
    end

    context "with a short password" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "rejects the reset" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "short", password_confirm: "short" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(error_text).to include("too short")
      end
    end

    context "with an expired nonce" do
      let(:nonce) { create(:user_password_reset_nonce) }

      before { nonce.update_columns(created_at: 7.hours.ago) }

      it "redirects with an expiry notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "hexerade1234", password_confirm: "hexerade1234" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Reset expired")
      end
    end

    context "with an invalid nonce" do
      it "redirects with an invalid token notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: "0", key: "doesnotexist", password: "hexerade1234", password_confirm: "hexerade1234" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Invalid reset token")
      end
    end

    context "with an excessively large UID" do
      it "redirects with an invalid token notice without raising" do
        expect do
          patch maintenance_user_password_reset_path,
                params: { uid: "212488730429208853042920885", key: "doesnotexist", password: "hexerade1234", password_confirm: "hexerade1234" }
        end.not_to raise_error

        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Invalid reset token")
      end
    end
  end
end
