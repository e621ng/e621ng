# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::LoginRemindersController do
  before { allow(RateLimiter).to receive(:throttle!).and_return(false) }

  describe "GET /maintenance/user/login_reminder/new" do
    it "returns 200" do
      get new_maintenance_user_login_reminder_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the turnstile widget when enabled" do
      allow(Danbooru.config.custom_configuration).to receive_messages(enable_turnstile?: true, turnstile_site_key: "test-site-key")
      get new_maintenance_user_login_reminder_path
      expect(response.body).to include('class="cf-turnstile" data-sitekey="test-site-key"')
    end
  end

  describe "POST /maintenance/user/login_reminder" do
    context "when the email matches a regular user" do
      let(:user) { create(:user) }

      it "sends a login reminder email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: user.email } } }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "redirects with the generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: user.email } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end

      it "counts the request against the IP and email limiters and still matches the user" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: " #{user.email.upcase}" } } }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(RateLimiter).to have_received(:throttle!).with("account_recovery:127.0.0.1", limit: 5, period: 1.hour)
        expect(RateLimiter).to have_received(:throttle!).with("account_recovery:email:#{user.email.downcase}", limit: 3, period: 1.hour)
      end
    end

    context "when the email matches a moderator" do
      let(:moderator) { create(:moderator_user) }

      it "does not send an email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: moderator.email } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "redirects with the same generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: moderator.email } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email is unknown" do
      it "does not send an email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: "nobody@example.com" } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "redirects with the same generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: "nobody@example.com" } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the email is blank" do
      it "does not send an email" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: "" } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
      end

      it "redirects with the same generic notice" do
        post maintenance_user_login_reminder_path, params: { user: { email: "" } }
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when the user param is missing" do
      it "redirects with the generic notice without raising" do
        expect { post maintenance_user_login_reminder_path }.not_to raise_error
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to include("If your email was on file")
      end
    end

    context "when rate limited by IP" do
      let(:user) { create(:user) }

      before do
        allow(RateLimiter).to receive(:throttle!).with("account_recovery:127.0.0.1", any_args).and_return(true)
        allow(TurnstileVerifier).to receive(:verify)
      end

      it "redirects with a throttle notice and sends nothing" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: user.email } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to eq("Too many requests. Try again later.")
        expect(TurnstileVerifier).not_to have_received(:verify)
      end
    end

    context "when rate limited by email" do
      let(:user) { create(:user) }

      before do
        allow(RateLimiter).to receive(:throttle!).with(a_string_starting_with("account_recovery:email:"), any_args).and_return(true)
      end

      it "shows the generic notice without sending" do
        expect { post maintenance_user_login_reminder_path, params: { user: { email: user.email } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
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
        expect { post maintenance_user_login_reminder_path, params: { user: { email: user.email } } }
          .not_to(change { ActionMailer::Base.deliveries.count })
        expect(response).to redirect_to(new_maintenance_user_login_reminder_path)
        expect(flash[:notice]).to eq("Captcha verification failed, please try again")
        expect(RateLimiter).not_to have_received(:throttle!).with(a_string_starting_with("account_recovery:email:"), any_args)
      end

      it "sends the mail when verification succeeds" do
        allow(TurnstileVerifier).to receive(:verify).and_return(true)
        expect { post maintenance_user_login_reminder_path, params: { user: { email: user.email }, "cf-turnstile-response" => "turnstile-token" } }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(TurnstileVerifier).to have_received(:verify).with("turnstile-token", "127.0.0.1")
      end
    end
  end
end
