# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                  FileMethods — corruption detection methods                 #
# --------------------------------------------------------------------------- #
#
# Covers:
#   - is_corrupt_gif?(file_path)
#   - is_corrupt?(file_path)
#
# Real fixture files are used where available.
# Vips::Error is simulated via allow().to receive() for the GIF corruption path
# that has no corresponding fixture.

RSpec.describe FileMethods, type: :model do
  # ----------------------------------------------------------------------- #
  describe "#is_corrupt_gif?" do
    context "with a valid animated GIF" do
      it "returns false" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("animated.gif").to_s
        expect(upload.is_corrupt_gif?(path)).to be false
      end
    end

    context "with a valid static GIF" do
      it "returns false" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("static.gif").to_s
        expect(upload.is_corrupt_gif?(path)).to be false
      end
    end

    context "when Vips raises an error" do
      it "returns true" do
        upload = build(:upload, file_ext: "gif")
        allow(Vips::Image).to receive(:gifload).and_raise(Vips::Error)
        expect(upload.is_corrupt_gif?("/fake/path.gif")).to be true
      end
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_corrupt?" do
    context "with a valid JPEG" do
      it "returns false" do
        upload = build(:upload, file_ext: "jpg")
        path = file_fixture("sample.jpg").to_s
        expect(upload.is_corrupt?(path)).to be false
      end
    end

    context "with a valid PNG" do
      it "returns false" do
        upload = build(:upload, file_ext: "png")
        path = file_fixture("sample.png").to_s
        expect(upload.is_corrupt?(path)).to be false
      end
    end

    context "with a corrupt JPEG fixture" do
      it "returns true" do
        upload = build(:upload, file_ext: "jpg")
        path = file_fixture("file_validator/corrupt.jpg").to_s
        expect(upload.is_corrupt?(path)).to be true
      end
    end

    context "with a valid animated GIF" do
      it "returns false" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("animated.gif").to_s
        expect(upload.is_corrupt?(path)).to be false
      end
    end

    context "with a non-image file extension" do
      it "returns false without touching the file" do
        upload = build(:upload, file_ext: "webm")
        # Non-existent path proves the file is never opened
        expect(upload.is_corrupt?("/nonexistent/path.webm")).to be false
      end
    end
  end
end
