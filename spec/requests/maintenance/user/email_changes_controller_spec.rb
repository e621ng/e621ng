# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::EmailChangesController do
  before { CurrentUser.ip_addr = "127.0.0.1" }

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:user) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /maintenance/user/email_change/new
  # ---------------------------------------------------------------------------

  describe "GET /maintenance/user/email_change/new" do
    context "as anonymous" do
      it "redirects to the login page" do
        get new_maintenance_user_email_change_path
        expect(response).to redirect_to(new_session_path(url: new_maintenance_user_email_change_path))
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "returns 200" do
        get new_maintenance_user_email_change_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /maintenance/user/email_change
  # ---------------------------------------------------------------------------

  describe "POST /maintenance/user/email_change" do
    context "as anonymous" do
      it "redirects to the login page" do
        post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "hexerade" } }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before do
        sign_in_as user
        allow(RateLimiter).to receive(:check_limit).and_return(false)
        allow(RateLimiter).to receive(:hit)
      end

      context "with a correct password and valid email" do
        it "redirects to home with a success notice" do
          post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "hexerade" } }
          expect(response).to redirect_to(home_users_path)
          expect(flash[:notice]).to eq("Email was updated")
        end

        it "updates the user's email" do
          expect do
            post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "hexerade" } }
          end.to(change { user.reload.email }.to("new@example.com"))
        end
      end

      context "with an incorrect password" do
        it "redirects to the new page with an error notice" do
          post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "wrongpassword" } }
          expect(response).to redirect_to(new_maintenance_user_email_change_path)
          expect(flash[:notice]).to include("Password was incorrect")
        end

        it "does not update the user's email" do
          expect do
            post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "wrongpassword" } }
          end.not_to(change { user.reload.email })
        end
      end

      context "when rate-limited" do
        before { allow(RateLimiter).to receive(:check_limit).and_return(true) }

        it "redirects to the new page with an error notice" do
          post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "hexerade" } }
          expect(response).to redirect_to(new_maintenance_user_email_change_path)
          expect(flash[:notice]).to include("Email changed too recently")
        end
      end

      context "when the user is banned" do
        before { allow(user).to receive(:is_blocked?).and_return(true) }

        it "returns 403" do
          post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "hexerade" } }
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when email verification is enabled" do
        let(:mail_message) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

        before do
          allow(Danbooru.config.custom_configuration).to receive(:enable_email_verification?).and_return(true)
          allow(Maintenance::User::EmailConfirmationMailer).to receive(:confirmation).and_return(mail_message)
        end

        it "sends a confirmation email" do
          post maintenance_user_email_change_path, params: { email_change: { email: "new@example.com", password: "hexerade" } }
          expect(Maintenance::User::EmailConfirmationMailer).to have_received(:confirmation).with(user)
          expect(mail_message).to have_received(:deliver_now)
        end

        context "with an invalid email format" do
          it "redirects to the new page with an error notice" do
            post maintenance_user_email_change_path, params: { email_change: { email: "not-an-email", password: "hexerade" } }
            expect(response).to redirect_to(new_maintenance_user_email_change_path)
            expect(flash[:notice]).to be_present
          end

          it "does not update the user's email" do
            expect do
              post maintenance_user_email_change_path, params: { email_change: { email: "not-an-email", password: "hexerade" } }
            end.not_to(change { user.reload.email })
          end
        end
      end
    end
  end
end
