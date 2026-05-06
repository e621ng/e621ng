# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::PasswordResetsController do
  describe "GET /maintenance/user/password_reset/new" do
    it "returns 200" do
      get new_maintenance_user_password_reset_path
      expect(response).to have_http_status(:ok)
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
  end

  describe "GET /maintenance/user/password_reset/edit" do
    context "with a valid nonce" do
      let(:nonce) { create(:user_password_reset_nonce) }

      it "returns 200" do
        get edit_maintenance_user_password_reset_path, params: { uid: nonce.user_id, key: nonce.key }
        expect(response).to have_http_status(:ok)
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
    end
  end

  describe "PATCH /maintenance/user/password_reset" do
    context "with a valid nonce and matching passwords" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "redirects with a success notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "newpassword1", password_confirm: "newpassword1" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Password reset")
      end

      it "destroys the nonce" do
        expect do
          patch maintenance_user_password_reset_path,
                params: { uid: nonce.user_id, key: nonce.key, password: "newpassword1", password_confirm: "newpassword1" }
        end.to change(UserPasswordResetNonce, :count).by(-1)
      end
    end

    context "with mismatched passwords" do
      let!(:nonce) { create(:user_password_reset_nonce) }

      it "redirects with an error notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "newpassword1", password_confirm: "different" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Passwords do not match")
      end

      it "does not destroy the nonce" do
        expect do
          patch maintenance_user_password_reset_path,
                params: { uid: nonce.user_id, key: nonce.key, password: "newpassword1", password_confirm: "different" }
        end.not_to change(UserPasswordResetNonce, :count)
      end
    end

    context "with an expired nonce" do
      let(:nonce) { create(:user_password_reset_nonce) }

      before { nonce.update_columns(created_at: 7.hours.ago) }

      it "redirects with an expiry notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: nonce.user_id, key: nonce.key, password: "newpassword1", password_confirm: "newpassword1" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Reset expired")
      end
    end

    context "with an invalid nonce" do
      it "redirects with an invalid token notice" do
        patch maintenance_user_password_reset_path,
              params: { uid: "0", key: "doesnotexist", password: "newpassword1", password_confirm: "newpassword1" }
        expect(response).to redirect_to(new_maintenance_user_password_reset_path)
        expect(flash[:notice]).to eq("Invalid reset token")
      end
    end
  end
end
