# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadsController do
  include_context "as admin"

  let(:member)  { create(:user) }
  let(:janitor) { create(:janitor_user) }
  let(:admin)   { create(:admin_user) }
  let(:upload)  { create(:upload, uploader: janitor) }

  # ---------------------------------------------------------------------------
  # GET /uploads/new
  # ---------------------------------------------------------------------------

  describe "GET /uploads/new" do
    it "redirects anonymous to the login page" do
      get new_upload_path
      expect(response).to redirect_to(new_session_path(url: new_upload_path))
    end

    it "returns 200 for a member" do
      sign_in_as member
      get new_upload_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a janitor" do
      sign_in_as janitor
      get new_upload_path
      expect(response).to have_http_status(:ok)
    end

    context "when uploads are disabled" do
      before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

      it "returns 403 for a member" do
        sign_in_as member
        get new_upload_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the uploads min level is set above member" do
      before { allow(Security::Lockdown).to receive(:uploads_min_level).and_return(User::Levels::JANITOR) }

      it "returns 403 for a member" do
        sign_in_as member
        get new_upload_path
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for a janitor" do
        sign_in_as janitor
        get new_upload_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the member is a newbie" do
      before do
        sign_in_as member
        allow(member).to receive(:can_upload_with_reason).and_return(:REJ_UPLOAD_NEWBIE)
      end

      it "returns 403" do
        get new_upload_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /uploads — index
  # ---------------------------------------------------------------------------

  describe "GET /uploads" do
    it "redirects anonymous to the login page" do
      get uploads_path
      expect(response).to redirect_to(new_session_path(url: uploads_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get uploads_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor" do
      sign_in_as janitor
      get uploads_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a janitor" do
      sign_in_as janitor
      get uploads_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /uploads/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /uploads/:id" do
    it "redirects anonymous to the login page" do
      get upload_path(upload)
      expect(response).to redirect_to(new_session_path(url: upload_path(upload)))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get upload_path(upload)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor viewing a pending upload" do
      sign_in_as janitor
      get upload_path(upload)
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON body containing the upload id for a janitor" do
      sign_in_as janitor
      get upload_path(upload, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => upload.id)
    end

    context "when the upload is completed and linked to a post" do
      let(:post_record) { create(:post) }

      before { upload.update_columns(status: "completed", post_id: post_record.id) }

      it "redirects to the post page for a janitor" do
        sign_in_as janitor
        get upload_path(upload)
        expect(response).to redirect_to(post_path(post_record.id))
      end
    end

    context "when the upload is completed but post_id is nil" do
      before { upload.update_columns(status: "completed", post_id: nil) }

      it "returns 200 instead of 500 for a janitor" do
        sign_in_as janitor
        get upload_path(upload)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("no longer exists")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /uploads — create
  # The action only defines a format.json responder; all tests use JSON format.
  # UploadService is always stubbed to avoid file I/O.
  # ---------------------------------------------------------------------------

  describe "POST /uploads" do
    let(:post_record) { create(:post) }
    let(:upload_double) do
      instance_double(
        Upload,
        invalid?:          false,
        is_duplicate?:     false,
        is_errored?:       false,
        post_id:           post_record.id,
        errors:            ActiveModel::Errors.new(Upload.new),
        sanitized_status:  "pending",
        duplicate_post_id: nil,
      )
    end
    let(:service_double) { instance_spy(UploadService, start!: upload_double, warnings: []) }
    let(:base_params) { { upload: { source: "https://example.com/image.jpg", tag_string: "tagme", rating: "s" } } }

    before { allow(UploadService).to receive(:new).and_return(service_double) }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post uploads_path, params: base_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 200 with a success payload for a member" do
      sign_in_as member
      post uploads_path(format: :json), params: base_params
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("success" => true, "post_id" => post_record.id)
    end

    context "when uploads are disabled" do
      before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

      it "returns 403 for a member" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the uploads min level is set above member" do
      before { allow(Security::Lockdown).to receive(:uploads_min_level).and_return(User::Levels::JANITOR) }

      it "returns 403 for a member" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the upload is invalid" do
      before do
        errors = ActiveModel::Errors.new(Upload.new)
        errors.add(:base, "uploader is limited")
        allow(upload_double).to receive_messages(invalid?: true, errors: errors)
      end

      it "returns 412 with reason: invalid for a member" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:precondition_failed)
        expect(response.parsed_body).to include("success" => false, "reason" => "invalid")
      end
    end

    context "when the upload is errored" do
      before do
        allow(upload_double).to receive_messages(is_errored?: true, sanitized_status: "error: Something went wrong...")
      end

      it "returns 412 with reason: invalid and the sanitized status for a member" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:precondition_failed)
        expect(response.parsed_body).to include("success" => false, "reason" => "invalid", "message" => "error: Something went wrong...")
      end
    end

    context "when the upload is a duplicate" do
      before do
        allow(upload_double).to receive_messages(is_duplicate?: true, duplicate_post_id: post_record.id)
      end

      it "returns 412 with reason: duplicate and the post id for a member" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:precondition_failed)
        expect(response.parsed_body).to include("success" => false, "reason" => "duplicate", "post_id" => post_record.id)
      end
    end

    context "when the service returns short warnings" do
      before { allow(service_double).to receive(:warnings).and_return(["Tag does not exist"]) }

      it "returns 200 and sets flash[:notice] to the warning text" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(response).to have_http_status(:ok)
        expect(flash[:notice]).to include("Tag does not exist")
      end
    end

    context "when the service returns warnings exceeding 1500 characters" do
      let(:long_warning) { "a" * 1501 }

      before do
        allow(service_double).to receive_messages(warnings: [long_warning], post: post_record)
        allow(Dmail).to receive(:create_automated)
      end

      it "calls Dmail.create_automated to send the notices" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(Dmail).to have_received(:create_automated)
      end

      it "sets flash[:notice] to the truncated-notice message" do
        sign_in_as member
        post uploads_path(format: :json), params: base_params
        expect(flash[:notice]).to include("dmailed")
      end
    end

    context "when locked_tags is submitted" do
      let(:locked_params) { { upload: base_params[:upload].merge(locked_tags: "meta") } }

      it "returns 403 for a regular member (unpermitted parameter)" do
        sign_in_as member
        post uploads_path(format: :json), params: locked_params
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for an admin (parameter is permitted)" do
        sign_in_as admin
        post uploads_path(format: :json), params: locked_params
        expect(response).to have_http_status(:ok)
      end
    end

    context "when locked_rating is submitted" do
      let(:locked_params) { { upload: base_params[:upload].merge(locked_rating: true) } }

      it "returns 403 for a regular member (unpermitted parameter)" do
        sign_in_as member
        post uploads_path(format: :json), params: locked_params
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for a privileged user (parameter is permitted)" do
        privileged = create(:privileged_user)
        sign_in_as privileged
        post uploads_path(format: :json), params: locked_params
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Upload lockdown — cross-cutting
  # ---------------------------------------------------------------------------

  describe "upload lockdown behaviour" do
    before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

    it "returns 403 for GET /uploads/new even for a member" do
      sign_in_as member
      get new_upload_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for POST /uploads even for a member" do
      sign_in_as member
      post uploads_path(format: :json), params: { upload: { rating: "s" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "still serves GET /uploads (index) for a janitor when uploads are disabled" do
      sign_in_as janitor
      get uploads_path
      expect(response).to have_http_status(:ok)
    end
  end
end
