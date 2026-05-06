# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       FileValidator#validate                                #
# --------------------------------------------------------------------------- #
#
# Integration-level smoke tests that call the top-level `validate` method so
# that SimpleCov registers coverage for the orchestration logic: the call
# sites, the `if record.is_video?` branch, and the `if @test_resolution`
# guard. Edge-case assertions are left to the focused unit spec files.

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

    context "with an invalid extension" do
      it "adds a file_ext error and skips all subsequent checks" do
        upload = build(:upload, file_ext: "bmp", file_size: 1000)
        catch(:abort) { FileValidator.new(upload, "").validate }
        expect(upload.errors[:file_ext]).to be_present
        # validate_file_size would have added a 'too small' error if :abort hadn't fired
        expect(upload.errors[:file_size]).to be_empty
      end
    end

    context "with test_resolution: false" do
      it "skips the resolution check" do
        path   = file_fixture("sample.jpg").to_s
        # Deliberately out-of-range dimensions that would normally trigger an error
        upload = build(:upload, file_ext: "jpg", file_size: File.size(path), image_width: 100, image_height: 100)
        FileValidator.new(upload, path, test_resolution: false).validate
        expect(upload.errors[:image_width]).to be_empty
        expect(upload.errors[:image_height]).to be_empty
      end
    end
  end
end
