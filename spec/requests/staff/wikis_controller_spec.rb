# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::WikisController do
  include_context "as admin"

  let(:staff_wiki) { create(:staff_wiki) }
  let(:member)     { create(:user) }
  let(:staff)      { create(:staff_user) }
  let(:admin)      { create(:admin_user) }

  # ---------------------------------------------------------------------------
  # GET /staff/wikis — index
  # ---------------------------------------------------------------------------

  describe "GET /staff/wikis" do
    it "redirects anonymous to the login page for HTML" do
      get staff_wikis_path
      expect(response).to redirect_to(new_session_path(url: staff_wikis_path))
    end

    it "returns 403 for anonymous JSON" do
      get staff_wikis_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get staff_wikis_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member" do
      sign_in_as staff
      get staff_wikis_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a staff member" do
      sign_in_as staff
      get staff_wikis_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "filters results by title search param" do
      staff_wiki
      sign_in_as staff
      get staff_wikis_path(format: :json, search: { title: staff_wiki.title })
      expect(response.parsed_body.pluck("id")).to include(staff_wiki.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/wikis/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /staff/wikis/:id" do
    it "redirects anonymous to the login page for HTML" do
      get staff_wiki_path(staff_wiki)
      expect(response).to redirect_to(new_session_path(url: staff_wiki_path(staff_wiki)))
    end

    it "returns 403 for anonymous JSON" do
      get staff_wiki_path(staff_wiki, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member" do
      sign_in_as staff
      get staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON with expected fields for a staff member" do
      sign_in_as staff
      get staff_wiki_path(staff_wiki, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => staff_wiki.id, "title" => staff_wiki.title)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/wikis/new — new
  # ---------------------------------------------------------------------------

  describe "GET /staff/wikis/new" do
    it "redirects anonymous to the login page" do
      get new_staff_wiki_path
      expect(response).to redirect_to(new_session_path(url: new_staff_wiki_path))
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get new_staff_wiki_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member" do
      sign_in_as staff
      get new_staff_wiki_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/wikis/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /staff/wikis/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_staff_wiki_path(staff_wiki)
      expect(response).to redirect_to(new_session_path(url: edit_staff_wiki_path(staff_wiki)))
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get edit_staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member" do
      sign_in_as staff
      get edit_staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/wikis — create
  # ---------------------------------------------------------------------------

  describe "POST /staff/wikis" do
    let(:valid_params)   { { staff_wiki: { title: "New Staff Wiki", body: "Valid body content." } } }
    let(:invalid_params) { { staff_wiki: { title: "", body: "Valid body content." } } }

    it "redirects anonymous to the login page for HTML" do
      post staff_wikis_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      post staff_wikis_path(format: :json), params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      post staff_wikis_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a staff member" do
      before { sign_in_as staff }

      it "creates a staff wiki" do
        expect { post staff_wikis_path, params: valid_params }.to change(StaffWiki, :count).by(1)
      end

      it "redirects after creation" do
        post staff_wikis_path, params: valid_params
        expect(response).to have_http_status(:redirect)
      end

      it "does not create a wiki with invalid params" do
        expect { post staff_wikis_path, params: invalid_params }.not_to change(StaffWiki, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /staff/wikis/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /staff/wikis/:id" do
    let(:update_params)  { { staff_wiki: { body: "Updated body content." } } }
    let(:invalid_params) { { staff_wiki: { title: "" } } }

    it "redirects anonymous to the login page for HTML" do
      patch staff_wiki_path(staff_wiki), params: update_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      patch staff_wiki_path(staff_wiki, format: :json), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      patch staff_wiki_path(staff_wiki), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "updates the body for a staff member" do
      sign_in_as staff
      patch staff_wiki_path(staff_wiki), params: update_params
      expect(staff_wiki.reload.body).to eq("Updated body content.")
    end

    it "redirects after a successful update for a staff member" do
      sign_in_as staff
      patch staff_wiki_path(staff_wiki), params: update_params
      expect(response).to have_http_status(:redirect)
    end

    it "does not update with an invalid title" do
      original_title = staff_wiki.title
      sign_in_as staff
      patch staff_wiki_path(staff_wiki), params: invalid_params
      expect(staff_wiki.reload.title).to eq(original_title)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /staff/wikis/:id — destroy (admin only)
  # ---------------------------------------------------------------------------

  describe "DELETE /staff/wikis/:id" do
    it "redirects anonymous to the login page for HTML" do
      delete staff_wiki_path(staff_wiki)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      delete staff_wiki_path(staff_wiki, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      delete staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a staff member" do
      sign_in_as staff
      delete staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the wiki for an admin" do
      sign_in_as admin
      staff_wiki
      expect { delete staff_wiki_path(staff_wiki) }.to change(StaffWiki, :count).by(-1)
    end

    it "redirects after destruction for an admin" do
      sign_in_as admin
      delete staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /staff/wikis/:id/revert — revert
  # ---------------------------------------------------------------------------

  describe "PUT /staff/wikis/:id/revert" do
    let(:original_body) { staff_wiki.body }
    let(:version) { staff_wiki.versions.first }

    before do
      original_body
      staff_wiki.update!(body: "Body after an edit.")
    end

    it "redirects anonymous to the login page for HTML" do
      put revert_staff_wiki_path(staff_wiki), params: { version_id: version.id }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      put revert_staff_wiki_path(staff_wiki, format: :json), params: { version_id: version.id }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      put revert_staff_wiki_path(staff_wiki), params: { version_id: version.id }
      expect(response).to have_http_status(:forbidden)
    end

    it "reverts to the given version for a staff member" do
      sign_in_as staff
      put revert_staff_wiki_path(staff_wiki), params: { version_id: version.id }
      expect(staff_wiki.reload.body).to eq(original_body)
    end

    it "redirects after revert for a staff member" do
      sign_in_as staff
      put revert_staff_wiki_path(staff_wiki), params: { version_id: version.id }
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/wikis/:id/claim — claim
  # ---------------------------------------------------------------------------

  describe "POST /staff/wikis/:id/claim" do
    it "redirects anonymous to the login page for HTML" do
      post claim_staff_wiki_path(staff_wiki)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      post claim_staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "sets the claimant to the current staff member" do
      sign_in_as staff
      post claim_staff_wiki_path(staff_wiki)
      expect(staff_wiki.reload.claimant_id).to eq(staff.id)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/wikis/:id/unclaim — unclaim
  # ---------------------------------------------------------------------------

  describe "POST /staff/wikis/:id/unclaim" do
    before { staff_wiki.update_columns(claimant_id: staff.id) }

    it "redirects anonymous to the login page for HTML" do
      post unclaim_staff_wiki_path(staff_wiki)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      post unclaim_staff_wiki_path(staff_wiki)
      expect(response).to have_http_status(:forbidden)
    end

    it "clears the claimant for a staff member" do
      sign_in_as staff
      post unclaim_staff_wiki_path(staff_wiki)
      expect(staff_wiki.reload.claimant_id).to be_nil
    end
  end
end
