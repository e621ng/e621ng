# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       StaffFile Normalizations                              #
# --------------------------------------------------------------------------- #

RSpec.describe StaffFile do
  include_context "as admin"

  let(:png_path)   { Rails.root.join("spec/fixtures/files/sample.png") }
  let(:png_upload) { Rack::Test::UploadedFile.new(png_path, "image/png") }

  # -------------------------------------------------------------------------
  # set_file_properties
  # -------------------------------------------------------------------------
  describe "#set_file_properties" do
    it "derives the file attributes from the uploaded file" do
      staff_file = create(:staff_file, file: png_upload)
      expect(staff_file.original_filename).to eq("sample.png")
      expect(staff_file.file_ext).to eq("png")
      expect(staff_file.md5).to eq(Digest::MD5.file(png_path).hexdigest)
      expect(staff_file.file_size).to eq(File.size(png_path))
    end

    it "defaults the title to the original filename when blank" do
      staff_file = create(:staff_file, file: png_upload, title: nil)
      expect(staff_file.title).to eq("sample.png")
    end

    it "keeps an explicitly provided title" do
      staff_file = create(:staff_file, file: png_upload, title: "Custom title")
      expect(staff_file.title).to eq("Custom title")
    end
  end

  # -------------------------------------------------------------------------
  # normalize_ext
  # -------------------------------------------------------------------------
  describe "#normalize_ext" do
    it "normalizes jpeg (and uppercase) to jpg" do
      upload = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.jpg"), "image/jpeg", original_filename: "sample.JPEG")
      staff_file = build(:staff_file, file: upload)
      staff_file.valid?
      expect(staff_file.file_ext).to eq("jpg")
    end
  end

  # -------------------------------------------------------------------------
  # initialize_storage_id
  # -------------------------------------------------------------------------
  describe "#initialize_storage_id" do
    it "assigns a 32-character hex storage_id on create" do
      staff_file = build(:staff_file)
      staff_file.valid?
      expect(staff_file.storage_id).to match(/\A[0-9a-f]{32}\z/)
    end

    it "preserves an explicitly provided storage_id" do
      staff_file = build(:staff_file, storage_id: "fixedstorageid")
      staff_file.valid?
      expect(staff_file.storage_id).to eq("fixedstorageid")
    end
  end

  # -------------------------------------------------------------------------
  # default_title
  # -------------------------------------------------------------------------
  describe "#default_title" do
    it "resets a cleared title to the original filename on update" do
      staff_file = create(:staff_file, file: png_upload, title: "Custom title")
      staff_file.update!(title: "")
      expect(staff_file.title).to eq(staff_file.original_filename)
    end
  end
end
