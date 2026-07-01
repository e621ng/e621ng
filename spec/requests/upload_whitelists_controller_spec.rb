# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadWhitelistsController do
  include_context "as admin"

  let(:admin)     { create(:admin_user) }
  let(:member)    { create(:user) }
  let(:whitelist) { create(:upload_whitelist) }

  # ---------------------------------------------------------------------------
  # GET /upload_whitelists — index
  # ---------------------------------------------------------------------------

  describe "GET /upload_whitelists" do
    it "returns 200 for anonymous" do
      get upload_whitelists_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get upload_whitelists_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get upload_whitelists_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get upload_whitelists_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /upload_whitelists/new — new
  # ---------------------------------------------------------------------------

  describe "GET /upload_whitelists/new" do
    it "redirects anonymous to the login page" do
      get new_upload_whitelist_path
      expect(response).to redirect_to(new_session_path(url: new_upload_whitelist_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get new_upload_whitelist_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_upload_whitelist_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /upload_whitelists — create
  # ---------------------------------------------------------------------------

  describe "POST /upload_whitelists" do
    let(:valid_params) do
      { upload_whitelist: { domain: "newsite\\.com", path: "\\/.+", reason: "Allowed", note: "Test", allowed: true, hidden: false } }
    end

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post upload_whitelists_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post upload_whitelists_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      post upload_whitelists_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "creates a record and redirects to the index on valid params" do
        expect { post upload_whitelists_path, params: valid_params }.to change(UploadWhitelist, :count).by(1)
        expect(response).to redirect_to(upload_whitelists_path)
      end

      it "does not create a record when domain is blank" do
        invalid_params = { upload_whitelist: { domain: "", path: "\\/.+", allowed: true } }
        expect { post upload_whitelists_path, params: invalid_params }.not_to change(UploadWhitelist, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /upload_whitelists/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /upload_whitelists/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_upload_whitelist_path(whitelist)
      expect(response).to redirect_to(new_session_path(url: edit_upload_whitelist_path(whitelist)))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get edit_upload_whitelist_path(whitelist)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_upload_whitelist_path(whitelist)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /upload_whitelists/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /upload_whitelists/:id" do
    let(:update_params) { { upload_whitelist: { domain: "updated\\.com", path: "\\/.+", allowed: true } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        patch upload_whitelist_path(whitelist), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch upload_whitelist_path(whitelist, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      patch upload_whitelist_path(whitelist), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "updates the record, sets a success flash, and redirects to the index" do
        patch upload_whitelist_path(whitelist), params: update_params
        expect(whitelist.reload.domain).to eq("updated\\.com")
        expect(flash[:notice]).to eq("Entry updated")
        expect(response).to redirect_to(upload_whitelists_path)
      end

      it "sets an error flash and redirects when domain is blank" do
        patch upload_whitelist_path(whitelist), params: { upload_whitelist: { domain: "", path: "\\/.+" } }
        expect(whitelist.reload.domain).to eq(whitelist.domain)
        expect(flash[:notice]).to be_present
        expect(flash[:notice]).not_to eq("Entry updated")
        expect(response).to redirect_to(upload_whitelists_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /upload_whitelists/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /upload_whitelists/:id" do
    it "redirects anonymous to the login page" do
      delete upload_whitelist_path(whitelist)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      delete upload_whitelist_path(whitelist)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the record and redirects for an admin" do
      whitelist_id = whitelist.id
      sign_in_as admin
      expect { delete upload_whitelist_path(whitelist) }.to change(UploadWhitelist, :count).by(-1)
      expect(UploadWhitelist.find_by(id: whitelist_id)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # GET /upload_whitelists/is_allowed — is_allowed
  # ---------------------------------------------------------------------------

  describe "GET /upload_whitelists/is_allowed" do
    # The default factory: domain="example\.com", path="\/.+" — matches http://example.com/foo
    before do
      create(:upload_whitelist)
      create(:blocked_upload_whitelist, domain: "blocked\\.com", path: "\\/.+")
    end

    it "returns is_allowed: true for a URL matching an allowed entry" do
      get is_allowed_upload_whitelists_path(format: :json), params: { url: "http://example.com/foo" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be true
    end

    it "returns is_allowed: false for a URL matching a blocked entry" do
      get is_allowed_upload_whitelists_path(format: :json), params: { url: "http://blocked.com/foo" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be false
    end

    it "returns is_allowed: false with a path-specific reason when the domain matches but the path does not" do
      # Path regex \/.+ requires at least one char after the slash; bare domain has no path
      get is_allowed_upload_whitelists_path(format: :json), params: { url: "http://example.com" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be false
      expect(response.parsed_body["reason"]).to include("path")
    end

    it "returns is_allowed: false for a URL whose domain is not in the whitelist" do
      get is_allowed_upload_whitelists_path(format: :json), params: { url: "http://unknown.example.org/foo" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be false
    end

    it "returns is_allowed: false with reason 'invalid domain' when url param is blank" do
      get is_allowed_upload_whitelists_path(format: :json), params: { url: "" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be false
      expect(response.parsed_body["reason"]).to eq("invalid domain")
    end

    it "returns is_allowed: false with reason 'invalid domain' when url param is missing" do
      get is_allowed_upload_whitelists_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be false
      expect(response.parsed_body["reason"]).to eq("invalid domain")
    end

    it "returns is_allowed: false with reason 'invalid domain' when url param is not a string" do
      get is_allowed_upload_whitelists_path(format: :json), params: { url: { nested: "value" } }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["is_allowed"]).to be false
      expect(response.parsed_body["reason"]).to eq("invalid domain")
    end

    it "is accessible without authentication" do
      get is_allowed_upload_whitelists_path(format: :json), params: { url: "http://example.com/foo" }
      expect(response).to have_http_status(:ok)
    end
  end
end
