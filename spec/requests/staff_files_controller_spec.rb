# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffFilesController do
  include_context "as admin"

  let(:member)      { create(:user) }
  let(:staff)       { create(:staff_user) }
  let(:other_staff) { create(:staff_user) }
  let(:admin)       { create(:admin_user) }

  let(:png_upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.png"), "image/png") }
  let(:txt_upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/staff_file.txt"), "text/plain") }
  let(:exe_upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/staff_file.txt"), "application/octet-stream", original_filename: "tool.exe") }

  let(:storage) { instance_spy(StorageManager::Local) }

  before do
    # Don't touch the filesystem during request specs.
    allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
  end

  # ---------------------------------------------------------------------------
  # Access control
  # ---------------------------------------------------------------------------
  describe "access control" do
    it "returns 403 for a non-staff member on index JSON" do
      sign_in_as member
      get staff_files_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a non-staff member on new" do
      sign_in_as member
      get new_staff_file_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a staff member on index" do
      sign_in_as staff
      get staff_files_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff_files — create
  # ---------------------------------------------------------------------------
  describe "POST /staff_files" do
    it "uploads a whitelisted file and records the uploader" do
      sign_in_as staff
      expect do
        post staff_files_path, params: { staff_file: { file: png_upload } }
      end.to change(StaffFile, :count).by(1)

      staff_file = StaffFile.last
      expect(staff_file.creator_id).to eq(staff.id)
      expect(staff_file.file_ext).to eq("png")
      expect(staff_file.original_filename).to eq("sample.png")
    end

    it "accepts a whitelisted non-media file" do
      sign_in_as staff
      expect do
        post staff_files_path, params: { staff_file: { file: txt_upload } }
      end.to change(StaffFile, :count).by(1)
      expect(StaffFile.last.file_ext).to eq("txt")
    end

    it "rejects a non-whitelisted extension" do
      sign_in_as staff
      expect do
        post staff_files_path(format: :json), params: { staff_file: { file: exe_upload } }
      end.not_to change(StaffFile, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a file that exceeds the size limit" do
      allow(Danbooru.config.custom_configuration).to receive(:staff_file_max_size).and_return(1)
      sign_in_as staff
      expect do
        post staff_files_path(format: :json), params: { staff_file: { file: png_upload } }
      end.not_to change(StaffFile, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "logs a mod action on successful upload" do
      sign_in_as staff
      expect do
        post staff_files_path, params: { staff_file: { file: png_upload } }
      end.to change { ModAction.where(action: "staff_file_create").count }.by(1)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /staff_files/:id — destroy
  # ---------------------------------------------------------------------------
  describe "DELETE /staff_files/:id" do
    it "lets a staff member delete their own file" do
      file = create(:staff_file, creator: staff)
      sign_in_as staff
      expect do
        delete staff_file_path(file)
      end.to change(StaffFile, :count).by(-1)
    end

    it "forbids deleting another staff member's file" do
      file = create(:staff_file, creator: other_staff)
      sign_in_as staff
      expect do
        delete staff_file_path(file, format: :json)
      end.not_to change(StaffFile, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "lets an admin delete anyone's file" do
      file = create(:staff_file, creator: other_staff)
      sign_in_as admin
      expect do
        delete staff_file_path(file)
      end.to change(StaffFile, :count).by(-1)
    end

    it "logs a mod action on deletion" do
      file = create(:staff_file, creator: staff)
      sign_in_as staff
      expect do
        delete staff_file_path(file)
      end.to change { ModAction.where(action: "staff_file_delete").count }.by(1)
    end
  end
end
