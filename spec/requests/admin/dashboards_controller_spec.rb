# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DashboardsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:admin)  { create(:admin_user) }
  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /admin/dashboard
  # ---------------------------------------------------------------------------

  describe "GET /admin/dashboard" do
    it "redirects anonymous to the login page" do
      get admin_dashboard_path
      expect(response).to redirect_to(new_session_path(url: admin_dashboard_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get admin_dashboard_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "returns 200" do
        get admin_dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
