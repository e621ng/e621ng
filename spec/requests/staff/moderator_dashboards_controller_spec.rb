# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::ModeratorDashboardsController do
  include_context "as admin"

  let(:admin)   { create(:admin_user) }
  let(:janitor) { create(:janitor_user) }
  let(:member)  { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /staff/moderator_dashboard
  # ---------------------------------------------------------------------------

  describe "GET /staff/moderator_dashboard" do
    it "redirects anonymous to the login page" do
      get staff_moderator_dashboard_path
      expect(response).to redirect_to(new_session_path(url: staff_moderator_dashboard_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get staff_moderator_dashboard_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "returns 200" do
        get staff_moderator_dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "returns 200" do
        get staff_moderator_dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
