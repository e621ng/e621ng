# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::ExceptionsController do
  include_context "as admin"

  let(:admin) { create(:admin_user) }
  let(:user)  { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /staff/exceptions
  # ---------------------------------------------------------------------------

  describe "GET /staff/exceptions" do
    it "redirects anonymous to the login page" do
      get staff_exceptions_path
      expect(response).to redirect_to(new_session_path(url: staff_exceptions_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get staff_exceptions_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get staff_exceptions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON response for an admin" do
      sign_in_as admin
      get staff_exceptions_path(format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "when searching" do
      let!(:target_log) { create(:exception_log, class_name: "ArgumentError", code: SecureRandom.uuid, version: "deadbeef") }
      let!(:other_log)  { create(:exception_log, class_name: "RuntimeError") }

      before { sign_in_as admin }

      it "filters by class_name" do
        get staff_exceptions_path(format: :json, search: { class_name: "ArgumentError" })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_an(Array)
        expect(body.pluck("class_name")).to all(eq("ArgumentError"))
        expect(body.pluck("class_name")).not_to include("RuntimeError")
      end

      it "filters by code" do
        get staff_exceptions_path(format: :json, search: { code: target_log.code })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck("code")).to include(target_log.code)
        expect(body.pluck("code")).not_to include(other_log.code)
      end

      it "filters by without_class_name" do
        get staff_exceptions_path(format: :json, search: { without_class_name: "RuntimeError" })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck("class_name")).not_to include("RuntimeError")
      end

      it "filters by commit (version)" do
        get staff_exceptions_path(format: :json, search: { commit: "deadbeef" })
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.pluck("code")).to include(target_log.code)
        expect(body.pluck("code")).not_to include(other_log.code)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/exceptions/:id
  # ---------------------------------------------------------------------------

  describe "GET /staff/exceptions/:id" do
    let!(:exception_log) { create(:exception_log) }

    it "redirects anonymous to the login page" do
      get staff_exception_path(exception_log)
      expect(response).to redirect_to(new_session_path(url: staff_exception_path(exception_log)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get staff_exception_path(exception_log)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin (HTML)" do
      sign_in_as admin
      get staff_exception_path(exception_log)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin (JSON)" do
      sign_in_as admin
      get staff_exception_path(exception_log, format: :json)
      expect(response).to have_http_status(:ok)
    end

    it "finds a record by UUID code" do
      sign_in_as admin
      get staff_exception_path(exception_log.code, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["code"]).to eq(exception_log.code)
    end

    it "returns 404 for a non-existent numeric ID" do
      sign_in_as admin
      get staff_exception_path(0)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # JSON scrubbing (E6SEC-515)
  # ---------------------------------------------------------------------------

  describe "JSON scrubbing" do
    let(:staff) { create(:staff_user) }
    let(:raw_message) { "Error from 1.2.3.4 and admin@example.com" }
    let!(:exception_log) do
      create(:exception_log, message: raw_message, extra_params: { "referrer" => "http://1.2.3.4/?e=a@b.com" })
    end

    it "scrubs the show response for staff below admin" do
      sign_in_as staff
      get staff_exception_path(exception_log, format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["message"]).to eq("Error from [IP PROTECTED] and [EMAIL PROTECTED]")
      expect(body["extra_params"]["referrer"]).not_to include("1.2.3.4", "a@b.com")
      expect(body).not_to have_key("ip_addr")
    end

    it "scrubs the index response for staff below admin" do
      sign_in_as staff
      get staff_exceptions_path(format: :json)
      expect(response).to have_http_status(:ok)
      row = response.parsed_body.find { |log| log["code"] == exception_log.code }
      expect(row["message"]).to eq("Error from [IP PROTECTED] and [EMAIL PROTECTED]")
    end

    it "returns the raw message for admins" do
      sign_in_as admin
      get staff_exception_path(exception_log, format: :json)
      expect(response.parsed_body["message"]).to eq(raw_message)
    end
  end
end
