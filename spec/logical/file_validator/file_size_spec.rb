# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    FileValidator#validate_file_size                         #
# --------------------------------------------------------------------------- #
#
# Covers three independent checks:
#   1. Minimum file size (> 16 bytes)
#   2. Per-extension maximum file size
#   3. APNG-specific maximum file size (subset of PNG)

RSpec.describe FileValidator, type: :model do
  describe "#validate_file_size" do
    let(:max_file_sizes) { Danbooru.config.max_file_sizes }

    def validator_for(upload, file_path = "")
      FileValidator.new(upload, file_path)
    end

    context "minimum size" do
      it "adds an error when file_size is 16 bytes (at/below minimum)" do
        upload = build(:upload, file_ext: "jpg", file_size: 16)
        validator_for(upload).validate_file_size(max_file_sizes)
        expect(upload.errors[:file_size]).to include("is too small")
      end

      it "is valid when file_size is 17 bytes (just above minimum)" do
        upload = build(:upload, file_ext: "jpg", file_size: 17)
        validator_for(upload).validate_file_size(max_file_sizes)
        expect(upload.errors[:file_size]).to be_empty
      end
    end

    context "per-extension maximum size" do
      it "adds an error when file_size exceeds the jpg maximum" do
        max = max_file_sizes.fetch("jpg")
        upload = build(:upload, file_ext: "jpg", file_size: max + 1)
        validator_for(upload).validate_file_size(max_file_sizes)
        expect(upload.errors[:file_size]).to include(include("is too large"))
      end

      it "is valid when file_size equals the jpg maximum" do
        max = max_file_sizes.fetch("jpg")
        upload = build(:upload, file_ext: "jpg", file_size: max)
        validator_for(upload).validate_file_size(max_file_sizes)
        expect(upload.errors[:file_size]).to be_empty
      end
    end

    context "APNG maximum size" do
      let(:apng_path) { file_fixture("animated.png").to_s }

      it "adds an error when an animated PNG exceeds the APNG maximum" do
        max = Danbooru.config.max_apng_file_size
        upload = build(:upload, file_ext: "png", file_size: max + 1)
        validator_for(upload, apng_path).validate_file_size(max_file_sizes)
        expect(upload.errors[:file_size]).to include(include("is too large"))
      end

      it "is valid when an animated PNG is at or below the APNG maximum" do
        max = Danbooru.config.max_apng_file_size
        upload = build(:upload, file_ext: "png", file_size: max)
        validator_for(upload, apng_path).validate_file_size(max_file_sizes)
        expect(upload.errors[:file_size]).to be_empty
      end

      it "does not apply APNG size limit to a static PNG" do
        max = Danbooru.config.max_apng_file_size
        static_path = file_fixture("sample.png").to_s
        upload = build(:upload, file_ext: "png", file_size: max + 1)
        validator_for(upload, static_path).validate_file_size(max_file_sizes)
        # Only the per-extension PNG limit (100 MB) applies, not the APNG limit,
        # so no error should be added here (max + 1 is still well under 100 MB).
        expect(upload.errors[:file_size]).to be_empty
      end
    end
  end
end
