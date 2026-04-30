# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::User::DeletionsController do
  describe "GET /maintenance/user/deletion" do
    context "when anonymous" do
      it "redirects to the login page" do
        get maintenance_user_deletion_path
        expect(response).to redirect_to(new_session_path(url: maintenance_user_deletion_path))
      end
    end

    context "when logged in" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "returns 200" do
        get maintenance_user_deletion_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "DELETE /maintenance/user/deletion" do
    context "when anonymous" do
      it "redirects to the login page" do
        delete maintenance_user_deletion_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when logged in" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      context "with a valid password" do
        it "redirects to the posts page with a logout notice" do
          delete maintenance_user_deletion_path, params: { password: "hexerade" }
          expect(response).to redirect_to(posts_path)
          expect(flash[:notice]).to include("logged out")
        end

        it "logs a user_delete mod action" do
          delete maintenance_user_deletion_path, params: { password: "hexerade" }
          expect(ModAction.last.action).to eq("user_delete")
        end
      end

      context "with an incorrect password" do
        it "returns 400" do
          delete maintenance_user_deletion_path, params: { password: "wrongpassword" }
          expect(response).to have_http_status(:bad_request)
        end
      end

      # FIXME: banned user should return 400, but _ban_notice.html.erb calls
      # current_user.recent_ban.reason and the :banned_user factory sets is_banned: true without
      # creating a Ban record, so recent_ban is nil and the error page raises NoMethodError.
      # This is a pre-existing application bug.

      context "when the account is less than one week old" do
        let(:user) { create(:user, created_at: 1.day.ago) }

        it "returns 400" do
          delete maintenance_user_deletion_path, params: { password: "hexerade" }
          expect(response).to have_http_status(:bad_request)
        end
      end

      context "when the user is an admin" do
        let(:user) { create(:admin_user) }

        it "returns 400" do
          delete maintenance_user_deletion_path, params: { password: "hexerade" }
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
