# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffNotesController do
  include_context "as admin"

  let(:target_user)   { create(:user) }
  let(:janitor)       { create(:janitor_user) }
  let(:other_janitor) { create(:janitor_user) }
  let(:admin)         { create(:admin_user) }
  let(:member)        { create(:user) }

  # Staff note created with `janitor` as creator, same pattern as blips_controller_spec.
  let(:staff_note) do
    orig = CurrentUser.user
    CurrentUser.user = janitor
    create(:staff_note, user: target_user)
  ensure
    CurrentUser.user = orig
  end

  # ---------------------------------------------------------------------------
  # GET /staff_notes — index
  # ---------------------------------------------------------------------------

  describe "GET /staff_notes" do
    it "redirects anonymous to the login page for HTML" do
      get staff_notes_path
      expect(response).to redirect_to(new_session_path(url: staff_notes_path))
    end

    it "returns 403 for anonymous JSON" do
      get staff_notes_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get staff_notes_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor" do
      sign_in_as janitor
      get staff_notes_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a janitor" do
      sign_in_as janitor
      get staff_notes_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_notes/new — new
  # ---------------------------------------------------------------------------

  describe "GET /staff_notes/new" do
    it "redirects anonymous to the login page" do
      get new_staff_note_path(user_id: target_user.id)
      expect(response).to redirect_to(new_session_path(url: new_staff_note_path(user_id: target_user.id)))
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get new_staff_note_path(user_id: target_user.id)
      expect(response).to have_http_status(:forbidden)
    end

    # NOTE: line 23 of the controller calls `respond_with(@note)` instead of
    # `respond_with(@staff_note)` — `@note` is nil. For a GET request the
    # responder still renders the view template, so the response is 200.
    it "returns 200 for a janitor" do
      sign_in_as janitor
      get new_staff_note_path(user_id: target_user.id)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff_notes — create
  # ---------------------------------------------------------------------------

  describe "POST /staff_notes" do
    let(:valid_params) { { user_id: target_user.id, staff_note: { body: "A test note body." } } }

    it "redirects anonymous to the login page for HTML" do
      post staff_notes_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      post staff_notes_path(format: :json), params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      post staff_notes_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "creates a staff note" do
        expect { post staff_notes_path, params: valid_params }.to change(StaffNote, :count).by(1)
      end

      it "sets a success flash notice" do
        post staff_notes_path, params: valid_params
        expect(flash[:notice]).to eq("Staff Note added")
      end

      it "redirects after creation" do
        post staff_notes_path, params: valid_params
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_notes/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /staff_notes/:id" do
    it "redirects anonymous to the login page for HTML" do
      get staff_note_path(staff_note)
      expect(response).to redirect_to(new_session_path(url: staff_note_path(staff_note)))
    end

    it "returns 403 for anonymous JSON" do
      get staff_note_path(staff_note, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get staff_note_path(staff_note)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor" do
      sign_in_as janitor
      get staff_note_path(staff_note)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff_notes/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /staff_notes/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_staff_note_path(staff_note)
      expect(response).to redirect_to(new_session_path(url: edit_staff_note_path(staff_note)))
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      get edit_staff_note_path(staff_note)
      expect(response).to have_http_status(:forbidden)
    end

    # check_edit_privilege is only applied to `update`, not `edit`, so any
    # staff member can view the edit form regardless of authorship.
    it "returns 200 for the janitor who created the note" do
      sign_in_as janitor
      get edit_staff_note_path(staff_note)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a janitor who did not create the note" do
      sign_in_as other_janitor
      get edit_staff_note_path(staff_note)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_staff_note_path(staff_note)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /staff_notes/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /staff_notes/:id" do
    let(:update_params) { { staff_note: { body: "Updated note body." } } }

    it "redirects anonymous to the login page for HTML" do
      patch staff_note_path(staff_note), params: update_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      patch staff_note_path(staff_note, format: :json), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      patch staff_note_path(staff_note), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor who did not create the note" do
      sign_in_as other_janitor
      patch staff_note_path(staff_note), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "updates the body for the janitor who created the note" do
      sign_in_as janitor
      patch staff_note_path(staff_note), params: update_params
      expect(staff_note.reload.body).to eq("Updated note body.")
    end

    it "redirects after update for the creator" do
      sign_in_as janitor
      patch staff_note_path(staff_note), params: update_params
      expect(response).to have_http_status(:redirect)
    end

    it "allows an admin to update any note" do
      sign_in_as admin
      patch staff_note_path(staff_note), params: update_params
      expect(staff_note.reload.body).to eq("Updated note body.")
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /staff_notes/:id/delete — soft delete
  # ---------------------------------------------------------------------------

  describe "PUT /staff_notes/:id/delete" do
    it "redirects anonymous to the login page for HTML" do
      put delete_staff_note_path(staff_note)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      put delete_staff_note_path(staff_note, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      put delete_staff_note_path(staff_note)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor who did not create the note" do
      sign_in_as other_janitor
      put delete_staff_note_path(staff_note)
      expect(response).to have_http_status(:forbidden)
    end

    it "soft-deletes the note for the creator janitor" do
      sign_in_as janitor
      expect { put delete_staff_note_path(staff_note) }.to change { staff_note.reload.is_deleted }.from(false).to(true)
    end

    it "redirects after deletion for the creator" do
      sign_in_as janitor
      put delete_staff_note_path(staff_note)
      expect(response).to have_http_status(:redirect)
    end

    it "allows an admin to delete any note" do
      sign_in_as admin
      expect { put delete_staff_note_path(staff_note) }.to change { staff_note.reload.is_deleted }.from(false).to(true)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /staff_notes/:id/undelete — undelete
  # ---------------------------------------------------------------------------

  describe "PUT /staff_notes/:id/undelete" do
    before { staff_note.update_columns(is_deleted: true) }

    it "redirects anonymous to the login page for HTML" do
      put undelete_staff_note_path(staff_note)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      put undelete_staff_note_path(staff_note, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      put undelete_staff_note_path(staff_note)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor who did not create the note" do
      sign_in_as other_janitor
      put undelete_staff_note_path(staff_note)
      expect(response).to have_http_status(:forbidden)
    end

    it "undeletes the note for the creator janitor" do
      sign_in_as janitor
      expect { put undelete_staff_note_path(staff_note) }.to change { staff_note.reload.is_deleted }.from(true).to(false)
    end

    it "redirects after undeleting for the creator" do
      sign_in_as janitor
      put undelete_staff_note_path(staff_note)
      expect(response).to have_http_status(:redirect)
    end

    it "allows an admin to undelete any note" do
      sign_in_as admin
      expect { put undelete_staff_note_path(staff_note) }.to change { staff_note.reload.is_deleted }.from(true).to(false)
    end
  end
end
