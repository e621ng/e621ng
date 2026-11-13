# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailsController do
  before { CurrentUser.ip_addr = "127.0.0.1" }

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member) { create(:user) }

  let(:unverified_member) do
    u = create(:user)
    u.mark_unverified!
    u
  end

  # ---------------------------------------------------------------------------
  # GET /email/resend_confirmation
  # ---------------------------------------------------------------------------

  describe "GET /email/resend_confirmation" do
    context "as anonymous" do
      it "redirects to the login page" do
        get resend_confirmation_email_path
        expect(response).to redirect_to(new_session_path(url: resend_confirmation_email_path))
      end
    end

    context "when the IP is banned" do
      before { allow(IpBan).to receive(:is_banned?).and_return(true) }

      it "redirects to home with an error notice" do
        get resend_confirmation_email_path
        expect(response).to redirect_to(home_users_path)
        expect(flash[:notice]).to eq("An error occurred trying to send an activation email")
      end
    end

    context "as a verified member" do
      before { sign_in_as member }

      it "returns 403" do
        get resend_confirmation_email_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an unverified member" do
      before { sign_in_as unverified_member }

      context "when the email is blacklisted" do
        before { allow(EmailBlacklist).to receive(:is_banned?).and_return(true) }

        it "returns 403" do
          get resend_confirmation_email_path
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when rate-limited" do
        before { allow(RateLimiter).to receive(:throttle!).and_return(true) }

        it "returns 403" do
          get resend_confirmation_email_path
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when all checks pass" do
        let(:mail_message) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

        before do
          allow(RateLimiter).to receive(:throttle!).and_return(false)
          allow(Maintenance::User::EmailConfirmationMailer).to receive(:confirmation).and_return(mail_message)
        end

        it "delivers a confirmation email" do
          get resend_confirmation_email_path
          expect(Maintenance::User::EmailConfirmationMailer).to have_received(:confirmation).with(unverified_member)
          expect(mail_message).to have_received(:deliver_now)
        end

        it "redirects to home with a success notice" do
          get resend_confirmation_email_path
          expect(response).to redirect_to(home_users_path)
          expect(flash[:notice]).to eq("Activation email resent")
        end

        it "rotates the verification key so earlier links stop working" do
          old_key = unverified_member.email_verification_key
          get resend_confirmation_email_path
          expect(unverified_member.reload.email_verification_key).to be_present
          expect(unverified_member.email_verification_key).not_to eq(old_key)
          expect(unverified_member.is_verified?).to be(false)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /email/activate_user
  # ---------------------------------------------------------------------------

  describe "GET /email/activate_user" do
    context "when the IP is banned" do
      before { allow(IpBan).to receive(:is_banned?).and_return(true) }

      it "redirects to home with an error notice" do
        get activate_user_email_path
        expect(response).to redirect_to(home_users_path)
        expect(flash[:notice]).to eq("An error occurred trying to activate your account")
      end
    end

    context "with no sig param" do
      it "redirects to the login page" do
        get activate_user_email_path
        expect(response).to redirect_to(new_session_path(url: activate_user_email_path))
      end
    end

    context "with an invalid sig param" do
      let(:bad_sig) { "this-is-not-a-valid-signature" }

      it "redirects to the login page" do
        get activate_user_email_path(sig: bad_sig)
        expect(response).to redirect_to(new_session_path(url: activate_user_email_path(sig: bad_sig)))
      end
    end

    context "with a valid sig" do
      let(:target_user) { unverified_member }
      let(:sig)         { activation_sig(target_user) }

      context "when the email is blacklisted" do
        before do
          sig # force DB creation before EmailBlacklist stub is installed
          allow(EmailBlacklist).to receive(:is_banned?).and_return(true)
        end

        it "redirects to the login page" do
          get activate_user_email_path(sig: sig)
          expect(response).to redirect_to(new_session_path(url: activate_user_email_path(sig: sig)))
        end
      end

      context "when the user is already verified" do
        let(:sig) { EmailLinkValidator.generate([member.id, User.generate_email_verification_key], :activate) }

        it "redirects to the login page" do
          get activate_user_email_path(sig: sig)
          expect(response).to redirect_to(new_session_path(url: activate_user_email_path(sig: sig)))
        end
      end

      context "when all checks pass" do
        it "marks the user as verified" do
          expect { get activate_user_email_path(sig: sig) }
            .to change { target_user.reload.is_verified? }.from(false).to(true)
        end

        it "redirects to home with a success notice" do
          get activate_user_email_path(sig: sig)
          expect(response).to redirect_to(home_users_path)
          expect(flash[:notice]).to eq("Account activated")
        end
      end
    end

    # E6SEC-509: links must stop working once the key they carry is rotated
    context "with a stale or malformed sig" do
      let(:target_user) { unverified_member }

      shared_examples "a rejected activation link" do
        it "does not verify the user" do
          expect { get activate_user_email_path(sig: sig) }
            .not_to(change { target_user.reload.is_verified? })
        end

        it "redirects to the login page" do
          get activate_user_email_path(sig: sig)
          expect(response).to redirect_to(new_session_path(url: activate_user_email_path(sig: sig)))
        end
      end

      context "when the sig carries only the user id (legacy format)" do
        let(:sig) { EmailLinkValidator.generate(target_user.id.to_s, :activate) }

        it_behaves_like "a rejected activation link"
      end

      context "when the sig carries a different key" do
        let(:sig) { EmailLinkValidator.generate([target_user.id, User.generate_email_verification_key], :activate) }

        it_behaves_like "a rejected activation link"
      end

      context "when the account still has the legacy placeholder key" do
        let(:sig) do
          target_user.update_columns(email_verification_key: "1")
          EmailLinkValidator.generate([target_user.id, nil], :activate)
        end

        it_behaves_like "a rejected activation link"
      end

      context "when the sig names a missing user" do
        let(:sig) { EmailLinkValidator.generate([0, User.generate_email_verification_key], :activate) }

        it "redirects to the login page" do
          get activate_user_email_path(sig: sig)
          expect(response).to redirect_to(new_session_path(url: activate_user_email_path(sig: sig)))
        end
      end

      context "when the email changed after the link was sent" do
        let(:sig) do
          old_sig = activation_sig(target_user)
          allow(Danbooru.config.custom_configuration).to receive(:enable_email_verification?).and_return(true)
          UserEmailChange.new(target_user, "new-address@example.com", "hexerade").process
          raise "email change failed: #{target_user.errors.full_messages}" if target_user.errors.any?
          old_sig
        end

        it_behaves_like "a rejected activation link"

        it "accepts a link for the new key" do
          sig
          new_sig = activation_sig(target_user.reload)
          expect { get activate_user_email_path(sig: new_sig) }
            .to change { target_user.reload.is_verified? }.from(false).to(true)
        end
      end

      context "when the user was unverified again after the link was sent" do
        let(:sig) do
          old_sig = activation_sig(target_user)
          target_user.mark_unverified!
          old_sig
        end

        it_behaves_like "a rejected activation link"
      end
    end
  end

  def activation_sig(user)
    EmailLinkValidator.generate([user.id, user.email_verification_key], :activate, 48.hours)
  end
end
