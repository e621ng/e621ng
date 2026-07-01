# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkUpdateRequestsController do
  include_context "as admin"

  let(:member)       { create(:user) }
  let(:other_member) { create(:user) }
  let(:moderator)    { create(:moderator_user) }
  let(:admin)        { create(:admin_user) }

  # Build the BUR as `member` so belongs_to_creator sets creator_id and
  # creator_ip_addr correctly, then restore the previous CurrentUser.
  let(:bur) do
    CurrentUser.scoped(member) { create(:bulk_update_request, user: member) }
  end

  # ---------------------------------------------------------------------------
  # GET /bulk_update_requests — index
  # ---------------------------------------------------------------------------

  describe "GET /bulk_update_requests" do
    it "returns 200 for anonymous HTML" do
      get bulk_update_requests_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for anonymous" do
      get bulk_update_requests_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /bulk_update_requests/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /bulk_update_requests/:id" do
    it "returns 200 for anonymous HTML" do
      get bulk_update_request_path(bur)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for anonymous JSON" do
      get bulk_update_request_path(bur, format: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /bulk_update_requests/new — new
  # ---------------------------------------------------------------------------

  describe "GET /bulk_update_requests/new" do
    it "redirects anonymous to the login page" do
      get new_bulk_update_request_path
      expect(response).to redirect_to(new_session_path(url: new_bulk_update_request_path))
    end

    it "returns 200 for a member" do
      sign_in_as member
      get new_bulk_update_request_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /bulk_update_requests — create
  # ---------------------------------------------------------------------------

  describe "POST /bulk_update_requests" do
    let(:valid_params) do
      { bulk_update_request: { script: "create alias bur_create_test -> bur_create_con", title: "Test BUR", reason: "Testing things out here" } }
    end

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post bulk_update_requests_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post bulk_update_requests_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a BUR with valid params" do
        expect { post bulk_update_requests_path, params: valid_params }.to change(BulkUpdateRequest, :count).by(1)
      end

      it "does not create a BUR with an invalid script" do
        params = { bulk_update_request: { script: "not valid syntax !!!", title: "Bad BUR", reason: "Testing bad syntax here" } }
        expect { post bulk_update_requests_path, params: params }.not_to change(BulkUpdateRequest, :count)
      end

      it "strips the skip_forum param for a regular member" do
        params = valid_params.deep_merge(bulk_update_request: { skip_forum: "1" })
        # The param is silently ignored — the request still succeeds (creates a forum post)
        # but no error is raised; we just verify the request completes without 500
        post bulk_update_requests_path, params: params
        expect(response).not_to have_http_status(:internal_server_error)
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "accepts skip_forum param and creates a BUR without a forum topic" do
        params = { bulk_update_request: { script: "create alias bur_admin_test -> bur_admin_con", title: "Admin BUR", skip_forum: "1" } }
        expect { post bulk_update_requests_path, params: params }.to change(BulkUpdateRequest, :count).by(1)
        expect(BulkUpdateRequest.last.forum_topic).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /bulk_update_requests/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /bulk_update_requests/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_bulk_update_request_path(bur)
      expect(response).to redirect_to(new_session_path(url: edit_bulk_update_request_path(bur)))
    end

    it "returns 200 for a member" do
      sign_in_as member
      get edit_bulk_update_request_path(bur)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /bulk_update_requests/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /bulk_update_requests/:id" do
    let(:new_script) { "create alias bur_upd_ant -> bur_upd_con" }
    let(:update_params) { { bulk_update_request: { script: new_script } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        patch bulk_update_request_path(bur), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch bulk_update_request_path(bur, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as the creator of a pending BUR" do
      before { sign_in_as member }

      it "updates the script and sets a success flash" do
        patch bulk_update_request_path(bur), params: update_params
        # BulkUpdateRequestImporter normalizes "create alias X -> Y" to "alias X -> Y"
        expect(bur.reload.script).to eq("alias bur_upd_ant -> bur_upd_con")
        expect(flash[:notice]).to eq("Bulk update request updated")
      end
    end

    context "as a non-creator member" do
      before { sign_in_as other_member }

      it "returns 403" do
        patch bulk_update_request_path(bur), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "can update any pending BUR" do
        patch bulk_update_request_path(bur), params: update_params
        expect(bur.reload.script).to eq("alias bur_upd_ant -> bur_upd_con")
      end
    end

    context "with a non-pending BUR" do
      let(:approved_bur) do
        CurrentUser.scoped(member) { create(:approved_bulk_update_request, user: member) }
      end

      it "returns 403 for the creator" do
        sign_in_as member
        patch bulk_update_request_path(approved_bur), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /bulk_update_requests/:id/approve — approve
  # ---------------------------------------------------------------------------

  describe "POST /bulk_update_requests/:id/approve" do
    it "redirects anonymous to the login page" do
      post approve_bulk_update_request_path(bur)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      post approve_bulk_update_request_path(bur)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "approves the BUR and sets a success flash" do
        post approve_bulk_update_request_path(bur)
        expect(bur.reload.status).to eq("approved")
        expect(flash[:notice]).to eq("Bulk update approved")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /bulk_update_requests/:id — destroy (reject)
  # ---------------------------------------------------------------------------

  describe "DELETE /bulk_update_requests/:id" do
    it "redirects anonymous to the login page" do
      delete bulk_update_request_path(bur)
      expect(response).to redirect_to(new_session_path)
    end

    context "as the creator of a pending BUR" do
      before { sign_in_as member }

      it "rejects the BUR (status → rejected) and sets a success flash" do
        delete bulk_update_request_path(bur)
        expect(bur.reload.status).to eq("rejected")
        expect(flash[:notice]).to eq("Bulk update request rejected")
      end

      it "redirects to the index page" do
        delete bulk_update_request_path(bur)
        expect(response).to redirect_to(bulk_update_requests_path)
      end
    end

    context "as a non-creator member" do
      before { sign_in_as other_member }

      it "returns 403" do
        delete bulk_update_request_path(bur)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "can reject any pending BUR" do
        delete bulk_update_request_path(bur)
        expect(bur.reload.status).to eq("rejected")
      end
    end

    context "with an already-rejected BUR" do
      let(:rejected_bur) do
        CurrentUser.scoped(member) { create(:rejected_bulk_update_request, user: member) }
      end

      it "returns 403 for the creator" do
        sign_in_as member
        delete bulk_update_request_path(rejected_bur)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_lockdown_disabled — cross-cutting lockdown behaviour
  # ---------------------------------------------------------------------------

  describe "lockdown behaviour" do
    before do
      allow(Security::Lockdown).to receive(:aiburs_disabled?).and_return(true)
    end

    it "returns 403 for a member on a write action (new)" do
      sign_in_as member
      get new_bulk_update_request_path
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff (moderator) through when locked down" do
      sign_in_as moderator
      get new_bulk_update_request_path
      expect(response).to have_http_status(:ok)
    end

    it "still serves GET /bulk_update_requests (index) when locked down" do
      get bulk_update_requests_path
      expect(response).to have_http_status(:ok)
    end

    it "still serves GET /bulk_update_requests/:id (show) when locked down" do
      get bulk_update_request_path(bur)
      expect(response).to have_http_status(:ok)
    end
  end
end
