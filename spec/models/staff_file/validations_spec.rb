# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         StaffFile Validations                               #
# --------------------------------------------------------------------------- #

RSpec.describe StaffFile do
  include_context "as admin"

  let(:png_upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.png"), "image/png") }
  let(:txt_upload) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/staff_file.txt"), "text/plain") }

  # -------------------------------------------------------------------------
  # file presence
  # -------------------------------------------------------------------------
  describe "file presence" do
    it "is invalid on create without a file" do
      staff_file = build(:staff_file, file: nil)
      expect(staff_file).not_to be_valid
      expect(staff_file.errors[:file]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # validate_file — extension whitelist
  # -------------------------------------------------------------------------
  describe "allowed extensions" do
    it "rejects an extension that is not whitelisted" do
      upload = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/staff_file.txt"), "application/octet-stream", original_filename: "tool.exe")
      staff_file = build(:staff_file, file: upload)
      expect(staff_file).not_to be_valid
      expect(staff_file.errors[:file]).to include("type 'exe' is not allowed")
    end

    it "accepts a whitelisted non-media type, trusting the filename" do
      staff_file = build(:staff_file, file: txt_upload)
      expect(staff_file).to be_valid, staff_file.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_file — size bounds
  # -------------------------------------------------------------------------
  describe "file size" do
    it "rejects a file that exceeds the maximum size" do
      allow(Danbooru.config.custom_configuration).to receive(:staff_file_max_size).and_return(1)
      staff_file = build(:staff_file, file: png_upload)
      expect(staff_file).not_to be_valid
      expect(staff_file.errors[:file].join).to include("is too large")
    end

    it "rejects a file that is too small" do
      tempfile = Tempfile.new(["tiny", ".txt"])
      tempfile.write("hi")
      tempfile.rewind
      upload = Rack::Test::UploadedFile.new(tempfile.path, "text/plain", original_filename: "tiny.txt")

      staff_file = build(:staff_file, file: upload)
      expect(staff_file).not_to be_valid
      expect(staff_file.errors[:file]).to include("is too small")
    ensure
      tempfile&.close!
    end
  end

  # -------------------------------------------------------------------------
  # validate_file — magic-byte / extension mismatch
  # -------------------------------------------------------------------------
  describe "content matches extension" do
    it "rejects an image whose bytes do not match the claimed extension" do
      upload = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.png"), "image/gif", original_filename: "sample.gif")
      staff_file = build(:staff_file, file: upload)
      expect(staff_file).not_to be_valid
      expect(staff_file.errors[:file]).to include("contents do not match its 'gif' extension")
    end
  end

  # -------------------------------------------------------------------------
  # storage_id uniqueness
  # -------------------------------------------------------------------------
  describe "storage_id uniqueness" do
    it "is invalid when another record already uses the storage_id" do
      existing = create(:staff_file)
      staff_file = build(:staff_file, file: png_upload)
      staff_file.storage_id = existing.storage_id
      expect(staff_file).not_to be_valid
      expect(staff_file.errors[:storage_id]).to be_present
    end
  end
end
