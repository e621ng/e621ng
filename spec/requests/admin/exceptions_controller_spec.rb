# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ExceptionsController do
  include_context "as admin"

  let(:admin) { create(:admin_user) }
  let(:user)  { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /admin/exceptions
  # ---------------------------------------------------------------------------

  describe "GET /admin/exceptions" do
    it "redirects anonymous to the login page" do
      get admin_exceptions_path
      expect(response).to redirect_to(new_session_path(url: admin_exceptions_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_exceptions_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get admin_exceptions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON response for an admin" do
      sign_in_as admin
      get admin_exceptions_path(format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "when searching" do
      let!(:target_log) { create(:exception_log, class_name: "ArgumentError", code: SecureRandom.uuid, version: "deadbeef") }
      let!(:other_log)  { create(:exception_log, class_name: "RuntimeError") }

      before { sign_in_as admin }

      it "filters by class_name" do
        get admin_exceptions_path(format: :json, search: { class_name: "ArgumentError" })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_an(Array)
        expect(body.pluck("class_name")).to all(eq("ArgumentError"))
        expect(body.pluck("class_name")).not_to include("RuntimeError")
      end

      it "filters by code" do
        get admin_exceptions_path(format: :json, search: { code: target_log.code })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck("code")).to include(target_log.code)
        expect(body.pluck("code")).not_to include(other_log.code)
      end

      it "filters by without_class_name" do
        get admin_exceptions_path(format: :json, search: { without_class_name: "RuntimeError" })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck("class_name")).not_to include("RuntimeError")
      end

      it "filters by commit (version)" do
        get admin_exceptions_path(format: :json, search: { commit: "deadbeef" })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck("code")).to include(target_log.code)
        expect(body.pluck("code")).not_to include(other_log.code)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/exceptions/:id
  # ---------------------------------------------------------------------------

  describe "GET /admin/exceptions/:id" do
    let!(:exception_log) { create(:exception_log) }

    it "redirects anonymous to the login page" do
      get admin_exception_path(exception_log)
      expect(response).to redirect_to(new_session_path(url: admin_exception_path(exception_log)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_exception_path(exception_log)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin (HTML)" do
      sign_in_as admin
      get admin_exception_path(exception_log)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin (JSON)" do
      sign_in_as admin
      get admin_exception_path(exception_log, format: :json)
      expect(response).to have_http_status(:ok)
    end

    it "finds a record by UUID code" do
      sign_in_as admin
      get admin_exception_path(exception_log.code, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["code"]).to eq(exception_log.code)
    end

    it "returns 404 for a non-existent numeric ID" do
      sign_in_as admin
      get admin_exception_path(0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
