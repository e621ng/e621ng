# frozen_string_literal: true

require "rails_helper"

RSpec.describe Security::DashboardController do
  include_context "as admin"

  let(:admin)  { create(:admin_user) }
  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /security/dashboard
  # ---------------------------------------------------------------------------

  describe "GET /security/dashboard" do
    it "redirects anonymous to the login page" do
      get security_dashboard_index_path
      expect(response).to redirect_to(new_session_path(url: security_dashboard_index_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get security_dashboard_index_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "returns 200" do
        get security_dashboard_index_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
