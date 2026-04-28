# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                  FileValidator#validate_file_integrity                      #
# --------------------------------------------------------------------------- #
#
# Only applies to images (is_image? == true). Delegates corruption detection
# to record.is_corrupt?(file_path).

RSpec.describe FileValidator, type: :model do
  describe "#validate_file_integrity" do
    context "with a corrupt JPEG" do
      it "adds an error" do
        path = file_fixture("file_validator/corrupt.jpg").to_s
        upload = build(:upload, file_ext: "jpg")
        FileValidator.new(upload, path).validate_file_integrity
        expect(upload.errors[:file]).to include("is corrupt")
      end
    end

    context "with a valid JPEG" do
      it "does not add an error" do
        path = file_fixture("sample.jpg").to_s
        upload = build(:upload, file_ext: "jpg")
        FileValidator.new(upload, path).validate_file_integrity
        expect(upload.errors[:file]).to be_empty
      end
    end

    context "with a video (non-image)" do
      it "does not add an error because is_image? is false" do
        path = file_fixture("file_validator/animated-vp8.webm").to_s
        upload = build(:upload, file_ext: "webm")
        FileValidator.new(upload, path).validate_file_integrity
        expect(upload.errors[:file]).to be_empty
      end
    end
  end
end
