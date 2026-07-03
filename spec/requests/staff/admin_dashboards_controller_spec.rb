# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::AdminDashboardsController do
  include_context "as admin"

  let(:admin)  { create(:admin_user) }
  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /staff/admin_dashboard
  # ---------------------------------------------------------------------------

  describe "GET /staff/admin_dashboard" do
    it "redirects anonymous to the login page" do
      get staff_admin_dashboard_path
      expect(response).to redirect_to(new_session_path(url: staff_admin_dashboard_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get staff_admin_dashboard_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "returns 200" do
        get staff_admin_dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
