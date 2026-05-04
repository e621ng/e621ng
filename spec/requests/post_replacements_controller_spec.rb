# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacementsController do
  include_context "as admin"

  let(:member)    { create(:user) }
  let(:replacer)  { create(:janitor_user) }   # can replace, cannot approve
  let(:approver)  { create(:approver_user) }  # can approve (and replace via can_approve_posts?)
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  let(:post_record) { create(:post) }
  # Factory bypasses validations (save!(validate: false)) and suppresses the
  # create_original_backup callback via is_backup: true.
  let(:replacement) { create(:post_replacement, post: post_record) }

  # ---------------------------------------------------------------------------
  # GET /post_replacements — index
  # ---------------------------------------------------------------------------

  describe "GET /post_replacements" do
    it "returns 200 for anonymous" do
      get post_replacements_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get post_replacements_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get post_replacements_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_replacements/new — new
  # ---------------------------------------------------------------------------

  describe "GET /post_replacements/new" do
    it "redirects anonymous to the login page" do
      get new_post_replacement_path(post_id: post_record.id)
      expect(response).to redirect_to(new_session_path(url: new_post_replacement_path(post_id: post_record.id)))
    end

    it "returns 403 for a regular member who cannot replace" do
      sign_in_as member
      get new_post_replacement_path(post_id: post_record.id)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor who can replace" do
      sign_in_as replacer
      get new_post_replacement_path(post_id: post_record.id)
      expect(response).to have_http_status(:ok)
    end

    context "when uploads are disabled" do
      before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

      it "returns 403 for a janitor" do
        sign_in_as replacer
        get new_post_replacement_path(post_id: post_record.id)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_replacements — create
  # The action only defines a format.json responder; all tests use JSON format.
  # ---------------------------------------------------------------------------

  describe "POST /post_replacements" do
    let(:base_params) { { post_id: post_record.id, post_replacement: { reason: "A sufficient replacement reason" } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post post_replacements_path, params: base_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post post_replacements_path(format: :json), params: base_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member who cannot replace" do
      sign_in_as member
      post post_replacements_path(format: :json), params: base_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 412 with an error payload when the replacer provides no file or URL" do
      sign_in_as replacer
      # No replacement_url or replacement_file supplied → validation fails.
      # Depending on the user's upload eligibility, the error may come from
      # user_is_not_limited or from set_file_name; either way the controller
      # returns 412 when errors are present.
      post post_replacements_path(format: :json), params: base_params
      expect(response).to have_http_status(:precondition_failed)
      expect(response.parsed_body).to include("success" => false)
      expect(response.parsed_body["message"]).to be_present
    end

    context "when uploads are disabled" do
      before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

      it "returns 403 for a replacer" do
        sign_in_as replacer
        post post_replacements_path(format: :json), params: base_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    # FIXME: Happy-path success requires stubbing FileValidator and
    # UploadService::Replacer (called inside PostReplacement#approve!).
    # Add once those classes have test seams or the controller is updated
    # to accept pre-built replacement objects.
  end

  # ---------------------------------------------------------------------------
  # PUT /post_replacements/:id/approve — approve
  # ---------------------------------------------------------------------------

  describe "PUT /post_replacements/:id/approve" do
    before do
      allow(PostReplacement).to receive(:find).and_return(replacement)
      allow(replacement).to receive(:approve!)
    end

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        put approve_post_replacement_path(replacement)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        put approve_post_replacement_path(replacement, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      put approve_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without can_approve_posts" do
      sign_in_as replacer
      put approve_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    context "when the target post is deleted" do
      before { post_record.update_columns(is_deleted: true) }

      it "returns 422 for an approver" do
        sign_in_as approver
        put approve_post_replacement_path(replacement)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    # The responders gem returns 204 No Content for PUT+JSON with no explicit render.
    it "returns 204 for an approver" do
      sign_in_as approver
      put approve_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:no_content)
    end

    # approver_only checks can_approve_posts?, not the moderator level flag.
    # A moderator without can_approve_posts is denied.
    it "returns 403 for a moderator without can_approve_posts" do
      sign_in_as moderator
      put approve_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /post_replacements/:id/reject — reject
  # reject! only does DB writes (update_attribute, PostEvent.add,
  # UserStatus.for_user.update_all, post.update_index) — no stubbing needed.
  # ---------------------------------------------------------------------------

  describe "PUT /post_replacements/:id/reject" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        put reject_post_replacement_path(replacement)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        put reject_post_replacement_path(replacement, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      put reject_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without can_approve_posts" do
      sign_in_as replacer
      put reject_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "changes the status to rejected for an approver" do
      sign_in_as approver
      expect { put reject_post_replacement_path(replacement, format: :json) }
        .to change { replacement.reload.status }.from("pending").to("rejected")
    end

    # approver_only checks can_approve_posts?, not the moderator level flag.
    it "returns 403 for a moderator without can_approve_posts" do
      sign_in_as moderator
      put reject_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /post_replacements/:id/toggle_penalize — toggle_penalize
  # toggle_penalize! requires an approved replacement and calls PostEvent.add
  # and UserStatus.for_user. Stub it to avoid needing uploader_on_approve set.
  # ---------------------------------------------------------------------------

  describe "PUT /post_replacements/:id/toggle_penalize" do
    let(:approved_replacement) { create(:approved_post_replacement, post: post_record) }

    before do
      allow(PostReplacement).to receive(:find).and_return(approved_replacement)
      allow(approved_replacement).to receive(:toggle_penalize!)
    end

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        put toggle_penalize_post_replacement_path(approved_replacement)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        put toggle_penalize_post_replacement_path(approved_replacement, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      put toggle_penalize_post_replacement_path(approved_replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without can_approve_posts" do
      sign_in_as replacer
      put toggle_penalize_post_replacement_path(approved_replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    # The responders gem returns 204 No Content for PUT+JSON with no explicit render.
    it "returns 204 for an approver" do
      sign_in_as approver
      put toggle_penalize_post_replacement_path(approved_replacement, format: :json)
      expect(response).to have_http_status(:no_content)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /post_replacements/:id/note — note
  # ---------------------------------------------------------------------------

  describe "PUT /post_replacements/:id/note" do
    it "creates a note for a moderator" do
      sign_in_as moderator

      put note_post_replacement_path(replacement), params: { note_content: "This is a test note" }

      expect(response).to have_http_status(:ok)
      expect(replacement.reload.note&.note).to eq("This is a test note")
    end

    it "returns 403 for a regular member" do
      sign_in_as member

      put note_post_replacement_path(replacement), params: { note_content: "This is a test note" }

      expect(response).to have_http_status(:forbidden)
      expect(replacement.reload.note).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_replacements/:id/promote — promote
  # promote! calls UploadService.new.start! — always stub to avoid file I/O.
  # ---------------------------------------------------------------------------

  describe "POST /post_replacements/:id/promote" do
    let(:upload_double) do
      instance_double(Upload,
                      errors: ActiveModel::Errors.new(Upload.new),
                      post:   post_record)
    end

    before do
      allow(PostReplacement).to receive(:find).and_return(replacement)
      allow(replacement).to receive(:promote!).and_return(upload_double)
    end

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post promote_post_replacement_path(replacement)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post promote_post_replacement_path(replacement, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      post promote_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without can_approve_posts" do
      sign_in_as replacer
      post promote_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    # The responders gem returns 201 Created for POST+JSON actions.
    it "returns 201 for an approver when promote! succeeds" do
      sign_in_as approver
      post promote_post_replacement_path(replacement, format: :json)
      expect(response).to have_http_status(:created)
    end

    # FIXME: When promote! returns nil (e.g. invalid status), the controller
    # calls @upload.errors.any? on nil, raising NoMethodError. Add a test for
    # the 422 path once the controller guards against a nil return value.
  end

  # ---------------------------------------------------------------------------
  # DELETE /post_replacements/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /post_replacements/:id" do
    it "redirects anonymous to the login page" do
      delete post_replacement_path(replacement)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      delete post_replacement_path(replacement)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver (admin_only action)" do
      sign_in_as approver
      delete post_replacement_path(replacement)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator (admin_only action)" do
      sign_in_as moderator
      delete post_replacement_path(replacement)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the record and returns 200 for an admin" do
      replacement_id = replacement.id
      sign_in_as admin
      expect { delete post_replacement_path(replacement) }.to change(PostReplacement, :count).by(-1)
      expect(PostReplacement.find_by(id: replacement_id)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Upload lockdown behaviour — cross-cutting
  # ---------------------------------------------------------------------------

  describe "upload lockdown behaviour" do
    before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

    it "returns 403 for GET /post_replacements/new even for a janitor" do
      sign_in_as replacer
      get new_post_replacement_path(post_id: post_record.id)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for POST /post_replacements even for a janitor" do
      sign_in_as replacer
      post post_replacements_path(format: :json), params: { post_id: post_record.id, post_replacement: { reason: "Some reason here" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "still serves GET /post_replacements (index) when uploads are disabled" do
      get post_replacements_path
      expect(response).to have_http_status(:ok)
    end
  end
end
