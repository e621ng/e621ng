# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthsController do
  include_context "as admin"

  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /auth/login
  # ---------------------------------------------------------------------------

  describe "GET /auth/login" do
    it "returns 200 for anonymous" do
      get login_auth_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get login_auth_path
      expect(response).to have_http_status(:ok)
    end

    it "returns an HTML response" do
      get login_auth_path
      expect(response.content_type).to include("text/html")
    end

    it "returns 406 for JSON format" do
      get login_auth_path(format: :json)
      expect(response).to have_http_status(:not_acceptable)
    end
  end
end
