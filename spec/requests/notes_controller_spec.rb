# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotesController do
  # Set a current user before each example so that factory callbacks that
  # require a current user do not raise NoMethodError inside `let` blocks.
  # Requests override this via the `sign_in_as` stub.
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:creator)      { create(:user) }
  let(:other_member) { create(:user) }
  let(:moderator)    { create(:moderator_user) }

  # Swap CurrentUser so belongs_to_creator records the right creator_id.
  let(:note) do
    orig = CurrentUser.user
    CurrentUser.user = creator
    create(:note)
  ensure
    CurrentUser.user = orig
  end

  let(:post_for_note)        { create(:post) }
  let(:valid_create_params)  { { note: { post_id: post_for_note.id, x: 10, y: 10, width: 100, height: 50, body: "Hello world." } } }
  let(:valid_update_params)  { { note: { body: "Updated body." } } }

  # ---------------------------------------------------------------------------
  # GET /notes/search — search
  # ---------------------------------------------------------------------------

  describe "GET /notes/search" do
    it "returns 200 for anonymous" do
      get search_notes_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as creator
      get search_notes_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /notes — index
  # ---------------------------------------------------------------------------

  describe "GET /notes" do
    it "returns 200 for anonymous" do
      get notes_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get notes_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /notes/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /notes/:id" do
    it "redirects to the post with an anchor for HTML" do
      get note_path(note)
      expect(response).to redirect_to(post_path(note.post, anchor: "note-#{note.id}"))
    end

    it "returns 200 for JSON" do
      get note_path(note, format: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /notes — create
  # ---------------------------------------------------------------------------

  describe "POST /notes" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post notes_path, params: valid_create_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post notes_path(format: :json), params: valid_create_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as creator }

      it "creates a note and returns JSON with note and dtext keys" do
        expect { post notes_path(format: :json), params: valid_create_params }.to change(Note, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("note", "dtext")
      end

      it "returns 422 with errors when the body is blank" do
        params = { note: { post_id: post_for_note.id, x: 10, y: 10, width: 100, height: 50, body: "" } }
        expect { post notes_path(format: :json), params: params }.not_to change(Note, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to include("success" => false, "reasons" => be_present)
      end

      it "returns 422 when the post is note-locked" do
        post_for_note.update_columns(is_note_locked: true)
        expect { post notes_path(format: :json), params: valid_create_params }.not_to change(Note, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["success"]).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /notes/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /notes/:id" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        patch note_path(note), params: valid_update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch note_path(note, format: :json), params: valid_update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as creator }

      it "updates the note and returns JSON with note, dtext, and posts keys" do
        patch note_path(note, format: :json), params: valid_update_params
        expect(response).to have_http_status(:ok)
        expect(note.reload.body).to eq("Updated body.")
        expect(response.parsed_body).to include("note", "dtext", "posts")
      end

      it "returns 422 with errors when the body is blank" do
        patch note_path(note, format: :json), params: { note: { body: "" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to include("success" => false, "reasons" => be_present)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /notes/:id — destroy (soft-delete)
  # ---------------------------------------------------------------------------

  describe "DELETE /notes/:id" do
    it "redirects anonymous to the login page" do
      delete note_path(note)
      expect(response).to redirect_to(new_session_path)
    end

    it "soft-deletes the note for a member" do
      sign_in_as creator
      expect { delete note_path(note) }.to change { note.reload.is_active }.from(true).to(false)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /notes/:id/revert — revert
  # ---------------------------------------------------------------------------

  describe "PUT /notes/:id/revert" do
    it "redirects anonymous to the login page" do
      put revert_note_path(note), params: { version_id: note.versions.first.id }
      expect(response).to redirect_to(new_session_path)
    end

    it "reverts the note to the specified version for a member" do
      sign_in_as creator
      version = note.versions.first
      put revert_note_path(note), params: { version_id: version.id }
      expect(response).to have_http_status(:redirect).or have_http_status(:ok)
    end
  end
end
