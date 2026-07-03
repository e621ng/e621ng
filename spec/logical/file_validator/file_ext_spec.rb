# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     FileValidator#validate_file_ext                         #
# --------------------------------------------------------------------------- #
#
# Verifies that only extensions present in the max_file_sizes hash are
# accepted, and that an invalid extension both adds an error and throws
# :abort to halt further validation.

RSpec.describe FileValidator, type: :model do
  describe "#validate_file_ext" do
    let(:max_file_sizes) { Danbooru.config.max_file_sizes }

    def validator_for(ext)
      upload = build(:upload, file_ext: ext)
      FileValidator.new(upload, "")
    end

    %w[jpg png gif webm mp4 webp].each do |ext|
      it "is valid for #{ext}" do
        v = validator_for(ext)
        catch(:abort) { v.validate_file_ext(max_file_sizes) }
        expect(v.record.errors[:file_ext]).to be_empty
      end
    end

    context "with an invalid extension" do
      subject(:validator) { validator_for("bmp") }

      it "adds an error" do
        catch(:abort) { validator.validate_file_ext(max_file_sizes) }
        expect(validator.record.errors[:file_ext]).to include(include("bmp is invalid"))
      end

      it "throws :abort" do
        expect { validator.validate_file_ext(max_file_sizes) }.to throw_symbol(:abort)
      end
    end
  end
end
