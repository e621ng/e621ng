# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DmailsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:bd_auditor)  { create(:bd_auditor_user) }
  let(:admin)       { create(:admin_user) }
  let(:user)        { create(:user) }
  let(:target_user) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /admin/users/:user_id/dmails
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/:user_id/dmails" do
    it "redirects anonymous to the login page" do
      get admin_user_dmails_path(target_user)
      expect(response).to redirect_to(new_session_path(url: admin_user_dmails_path(target_user)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_user_dmails_path(target_user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an admin without the bd_auditor flag" do
      sign_in_as admin
      get admin_user_dmails_path(target_user)
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_auditor" do
      before { sign_in_as bd_auditor }

      it "returns 200" do
        get admin_user_dmails_path(target_user)
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON response" do
        get admin_user_dmails_path(target_user, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "lists only dmails owned by the target user" do
        owned_dmail = create(:dmail, to: target_user, from: user)
        other_dmail = create(:dmail, to: user, from: target_user)
        get admin_user_dmails_path(target_user, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(owned_dmail.id)
        expect(ids).not_to include(other_dmail.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/users/:user_id/dmails/:id
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/:user_id/dmails/:id" do
    let(:dmail) { create(:dmail, to: target_user, from: user) }

    it "redirects anonymous to the login page" do
      get admin_user_dmail_path(target_user, dmail)
      expect(response).to redirect_to(new_session_path(url: admin_user_dmail_path(target_user, dmail)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_user_dmail_path(target_user, dmail)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an admin without the bd_auditor flag" do
      sign_in_as admin
      get admin_user_dmail_path(target_user, dmail)
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_auditor" do
      before { sign_in_as bd_auditor }

      it "returns 200" do
        get admin_user_dmail_path(target_user, dmail)
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON response" do
        get admin_user_dmail_path(target_user, dmail, format: :json)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
