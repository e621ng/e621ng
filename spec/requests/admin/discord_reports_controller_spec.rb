# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DiscordReportsController do
  let(:user)  { create(:user) }
  let(:admin) { create(:admin_user) }

  describe "GET /admin/discord_reports" do
    it "redirects anonymous to the login page" do
      get admin_destroyed_posts_path
      expect(response).to redirect_to(new_session_path(url: admin_destroyed_posts_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_destroyed_posts_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 and renders reports for an admin" do
      sign_in_as admin
      get admin_discord_reports_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("JANITOR REPORT")
      expect(response.body).to include("MODERATOR REPORT")
      expect(response.body).to include("AIBUR report")
    end
  end
end
