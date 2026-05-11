# frozen_string_literal: true

require "rails_helper"

RSpec.describe BlipsController do
  before { skip "Blips routes not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:blips_path) }

  include_context "as admin"

  let(:creator)      { create(:user) }
  let(:other_member) { create(:user) }
  let(:janitor)      { create(:janitor_user) }
  let(:moderator)    { create(:moderator_user) }
  let(:admin)        { create(:admin_user) }
  # belongs_to_creator only sets creator_ip_addr when creator_id is nil, so
  # passing creator: directly would leave creator_ip_addr null. Set CurrentUser
  # to the desired creator when building the record instead.
  let(:blip) do
    CurrentUser.scoped(creator) { create(:blip) }
  end

  # ---------------------------------------------------------------------------
  # GET /blips — index
  # ---------------------------------------------------------------------------

  describe "GET /blips" do
    it "returns 200 for anonymous" do
      get blips_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get blips_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as creator
      get blips_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /blips/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /blips/:id" do
    it "returns 200 for a visible blip when anonymous" do
      get blip_path(blip)
      expect(response).to have_http_status(:ok)
    end

    context "with a deleted blip" do
      before { blip.update_columns(is_deleted: true) }

      it "returns 200 for the creator" do
        sign_in_as creator
        get blip_path(blip)
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for a janitor" do
        sign_in_as janitor
        get blip_path(blip)
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 for another member" do
        sign_in_as other_member
        get blip_path(blip)
        expect(response).to have_http_status(:forbidden)
      end

      it "redirects anonymous to the login page" do
        get blip_path(blip)
        expect(response).to redirect_to(new_session_path(url: blip_path(blip)))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /blips/new — new
  # ---------------------------------------------------------------------------

  describe "GET /blips/new" do
    it "redirects anonymous to the login page" do
      get new_blip_path
      expect(response).to redirect_to(new_session_path(url: new_blip_path))
    end

    it "returns 200 for a signed-in member" do
      sign_in_as creator
      get new_blip_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /blips — create
  # ---------------------------------------------------------------------------

  describe "POST /blips" do
    let(:valid_params) { { blip: { body: "This is a valid blip body." } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post blips_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post blips_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as creator }

      it "creates a blip and sets a success flash" do
        expect { post blips_path, params: valid_params }.to change(Blip, :count).by(1)
        expect(flash[:notice]).to eq("Blip posted")
      end

      it "sets a non-success flash when the body is blank" do
        expect { post blips_path, params: { blip: { body: "" } } }.not_to change(Blip, :count)
        expect(flash[:notice]).to be_present
        expect(flash[:notice]).not_to eq("Blip posted")
      end

      it "creates a response blip with a valid response_to" do
        parent = blip
        post blips_path, params: { blip: { body: "A valid reply body.", response_to: parent.id } }
        expect(Blip.last.response_to).to eq(parent.id)
      end

      it "does not create a blip when response_to references a non-existent blip" do
        expect { post blips_path, params: { blip: { body: "A valid body.", response_to: 0 } } }.not_to change(Blip, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /blips/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /blips/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_blip_path(blip)
      expect(response).to redirect_to(new_session_path(url: edit_blip_path(blip)))
    end

    it "returns 200 for the creator within 5 minutes of creation" do
      sign_in_as creator
      get edit_blip_path(blip)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a non-creator member on a fresh blip" do
      sign_in_as other_member
      get edit_blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    context "with a blip older than 5 minutes" do
      let(:old_blip) do
        CurrentUser.scoped(creator) { create(:blip).tap { |b| b.update_columns(created_at: 6.minutes.ago) } }
      end

      it "redirects back (BlipTooOld) for a non-admin user via HTML" do
        sign_in_as creator
        get edit_blip_path(old_blip)
        expect(response).to redirect_to(blips_path)
      end

      it "returns 422 for a non-admin user via JSON" do
        sign_in_as creator
        get edit_blip_path(old_blip, format: :json)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 200 for an admin regardless of blip age" do
        sign_in_as admin
        get edit_blip_path(old_blip)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /blips/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /blips/:id" do
    let(:update_params) { { blip: { body: "Updated blip body." } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        patch blip_path(blip), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch blip_path(blip, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as the creator within 5 minutes" do
      before { sign_in_as creator }

      it "updates the body and sets a success flash" do
        patch blip_path(blip), params: update_params
        expect(blip.reload.body).to eq("Updated blip body.")
        expect(flash[:notice]).to eq("Blip updated")
      end

      it "ignores response_to in update params (param stripping)" do
        parent = create(:blip) # created as admin (CurrentUser from before block), any valid blip id suffices
        original_response_to = blip.response_to
        patch blip_path(blip), params: { blip: { body: "Updated body.", response_to: parent.id } }
        expect(blip.reload.response_to).to eq(original_response_to)
      end
    end

    it "returns 403 for a non-creator member" do
      sign_in_as other_member
      patch blip_path(blip), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "with a blip older than 5 minutes" do
      let(:old_blip) do
        CurrentUser.scoped(creator) { create(:blip).tap { |b| b.update_columns(created_at: 6.minutes.ago) } }
      end

      it "redirects back (BlipTooOld) for the creator via HTML" do
        sign_in_as creator
        patch blip_path(old_blip), params: update_params
        expect(response).to redirect_to(blips_path)
      end

      it "returns 422 for the creator via JSON" do
        sign_in_as creator
        patch blip_path(old_blip, format: :json), params: update_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "allows an admin to update regardless of blip age" do
        sign_in_as admin
        patch blip_path(old_blip), params: update_params
        expect(old_blip.reload.body).to eq("Updated blip body.")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /blips/:id/delete — soft delete
  # ---------------------------------------------------------------------------

  describe "POST /blips/:id/delete" do
    it "redirects anonymous to the login page" do
      post delete_blip_path(blip)
      expect(response).to redirect_to(new_session_path)
    end

    it "soft-deletes the blip for the creator" do
      sign_in_as creator
      expect { post delete_blip_path(blip) }.to change { blip.reload.is_deleted }.from(false).to(true)
    end

    it "soft-deletes any blip for a moderator" do
      sign_in_as moderator
      expect { post delete_blip_path(blip) }.to change { blip.reload.is_deleted }.from(false).to(true)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      post delete_blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-creator non-moderator member" do
      sign_in_as other_member
      post delete_blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when the creator tries to delete a warned blip" do
      blip.user_warned!(:warning, moderator)
      sign_in_as creator
      post delete_blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects back with a notice if the blip is already deleted" do
      blip.delete!
      sign_in_as creator
      post delete_blip_path(blip)
      expect(response).to redirect_to(blips_path)
      expect(flash[:alert]).to eq("Blip is already deleted")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /blips/:id/undelete — undelete
  # ---------------------------------------------------------------------------

  describe "POST /blips/:id/undelete" do
    before { blip.update_columns(is_deleted: true) }

    it "redirects anonymous to the login page" do
      post undelete_blip_path(blip)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as creator
      post undelete_blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      post undelete_blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "undeletes the blip for a moderator" do
      sign_in_as moderator
      expect { post undelete_blip_path(blip) }.to change { blip.reload.is_deleted }.from(true).to(false)
    end

    it "redirects back with a notice if the blip is not deleted" do
      blip.undelete!
      sign_in_as moderator
      post undelete_blip_path(blip)
      expect(response).to redirect_to(blips_path)
      expect(flash[:alert]).to eq("Blip is not deleted")
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /blips/:id — hard destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /blips/:id" do
    it "redirects anonymous to the login page" do
      delete blip_path(blip)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as creator
      delete blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      delete blip_path(blip)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the blip and sets a success flash for an admin" do
      blip_id = blip.id
      sign_in_as admin
      expect { delete blip_path(blip) }.to change(Blip, :count).by(-1)
      expect(Blip.find_by(id: blip_id)).to be_nil
      expect(flash[:notice]).to eq("Blip destroyed")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /blips/:id/warning — warning
  # ---------------------------------------------------------------------------

  describe "POST /blips/:id/warning" do
    it "redirects anonymous to the login page" do
      post warning_blip_path(blip), params: { record_type: "warning" }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as creator
      post warning_blip_path(blip), params: { record_type: "warning" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      post warning_blip_path(blip), params: { record_type: "warning" }
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "applies a warning, sets the warning user, and returns JSON with an html key" do
        post warning_blip_path(blip), params: { record_type: "warning" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("html")
        expect(blip.reload.warning_type).to eq("warning")
        expect(blip.reload.warning_user).to eq(moderator)
      end

      it "applies a record warning" do
        post warning_blip_path(blip), params: { record_type: "record" }
        expect(blip.reload.warning_type).to eq("record")
      end

      it "removes a warning with unmark and returns JSON with an html key" do
        blip.user_warned!(:warning, moderator)
        post warning_blip_path(blip), params: { record_type: "unmark" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("html")
        expect(blip.reload.warning_type).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_lockdown_disabled — cross-cutting behaviour
  # ---------------------------------------------------------------------------

  describe "lockdown behaviour" do
    before do
      allow(Security::Lockdown).to receive(:blips_disabled?).and_return(true)
    end

    it "returns 403 for a non-staff member on a write action" do
      sign_in_as creator
      get new_blip_path
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff (janitor) through when locked down" do
      sign_in_as janitor
      get new_blip_path
      expect(response).to have_http_status(:ok)
    end

    it "still serves GET /blips (index) when locked down" do
      get blips_path
      expect(response).to have_http_status(:ok)
    end

    it "still serves GET /blips/:id (show) when locked down" do
      get blip_path(blip)
      expect(response).to have_http_status(:ok)
    end
  end
end
