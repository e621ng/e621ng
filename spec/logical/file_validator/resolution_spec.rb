# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   FileValidator#validate_resolution                         #
# --------------------------------------------------------------------------- #
#
# Guards against images that are too large (by megapixels, width, or height)
# or too small (by width or height). The min_width value is used for both
# minimum width and minimum height per the source implementation.
#
# All tests set image dimensions directly on the Upload record; no real file
# is needed because validate_resolution reads only record.image_width /
# record.image_height.

RSpec.describe FileValidator, type: :model do
  describe "#validate_resolution" do
    let(:max_width)  { Danbooru.config.max_image_width }
    let(:max_height) { Danbooru.config.max_image_height }
    let(:min_width)  { Danbooru.config.min_image_width }

    def validator_for(width, height)
      upload = build(:upload, file_ext: "jpg", file_size: 1000, image_width: width, image_height: height)
      FileValidator.new(upload, "").tap do |v|
        v.validate_resolution(max_width, max_height, min_width)
      end
    end

    context "when the resolution exceeds the megapixel cap" do
      it "adds a resolution error" do
        # 15_001 × 15_001 = 225_030_001 px > 225_000_000 px cap
        v = validator_for(15_001, 15_001)
        expect(v.record.errors[:base]).to include(include("image resolution is too large"))
      end
    end

    context "when the width exceeds max_width (but total resolution is within cap)" do
      it "adds an image_width error" do
        # 15_001 × 500 is well under the megapixel cap
        v = validator_for(15_001, 500)
        expect(v.record.errors[:image_width]).to include(include("is too large"))
      end
    end

    context "when the height exceeds max_height (but total resolution is within cap)" do
      it "adds an image_height error" do
        v = validator_for(500, 15_001)
        expect(v.record.errors[:image_height]).to include(include("is too large"))
      end
    end

    context "when the width is below min_width" do
      it "adds an image_width error" do
        v = validator_for(255, 500)
        expect(v.record.errors[:image_width]).to include(include("is too small"))
      end
    end

    context "when the height is below min_width" do
      it "adds an image_height error" do
        v = validator_for(500, 255)
        expect(v.record.errors[:image_height]).to include(include("is too small"))
      end
    end

    context "with a valid resolution" do
      it "adds no errors" do
        v = validator_for(1920, 1080)
        expect(v.record.errors).to be_empty
      end
    end
  end
end
