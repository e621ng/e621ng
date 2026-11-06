# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       FileValidator#validate                                #
# --------------------------------------------------------------------------- #
#
# Integration-level smoke tests that call the top-level `validate` method so
# that SimpleCov registers coverage for the orchestration logic: the call
# sites and the `if record.is_video?` branch. Edge-case assertions are left
# to the focused unit spec files.

RSpec.describe FileValidator, type: :model do
  describe "#validate" do
    context "with a valid image" do
      it "adds no errors" do
        path   = file_fixture("sample.jpg").to_s
        upload = build(:upload, file_ext: "jpg", file_size: File.size(path), image_width: 500, image_height: 500)
        FileValidator.new(upload, path).validate
        expect(upload.errors).to be_empty
      end
    end

    context "with a valid video" do
      it "adds no errors and exercises the is_video? branch" do
        path   = file_fixture("file_validator/animated-vp8.webm").to_s
        upload = build(:upload, file_ext: "webm", file_size: File.size(path), image_width: 500, image_height: 500)
        FileValidator.new(upload, path).validate
        expect(upload.errors).to be_empty
      end
    end

    context "with an image over the resolution limit" do
      it "rejects it without decoding the file" do
        path   = file_fixture("sample.jpg").to_s
        upload = build(:upload, file_ext: "jpg", file_size: File.size(path), image_width: 15_001, image_height: 15_001)
        allow(upload).to receive(:is_corrupt?)
        FileValidator.new(upload, path).validate
        expect(upload.errors[:base]).to include(include("image resolution is too large"))
        expect(upload).not_to have_received(:is_corrupt?)
      end
    end

    context "with a video over the resolution limit" do
      it "rejects it without probing the video" do
        path   = file_fixture("file_validator/animated-vp8.webm").to_s
        upload = build(:upload, file_ext: "webm", file_size: File.size(path), image_width: 15_001, image_height: 500)
        allow(upload).to receive(:video)
        FileValidator.new(upload, path).validate
        expect(upload.errors[:image_width]).to include(include("is too large"))
        expect(upload).not_to have_received(:video)
      end
    end

    context "when the record already has errors from other validations" do
      it "still checks the file" do
        path   = file_fixture("file_validator/corrupt.jpg").to_s
        upload = build(:upload, file_ext: "jpg", file_size: File.size(path), image_width: 500, image_height: 500)
        upload.errors.add(:md5, "duplicate")
        FileValidator.new(upload, path).validate
        expect(upload.errors[:file]).to include("is corrupt")
      end
    end

    context "with an invalid extension" do
      it "adds a file_ext error and skips all subsequent checks" do
        upload = build(:upload, file_ext: "bmp", file_size: 1000)
        catch(:abort) { FileValidator.new(upload, "").validate }
        expect(upload.errors[:file_ext]).to be_present
        # validate_file_size would have added a 'too small' error if :abort hadn't fired
        expect(upload.errors[:file_size]).to be_empty
      end
    end
  end
end
