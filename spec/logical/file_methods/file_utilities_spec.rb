# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                  FileMethods — file utility methods                         #
# --------------------------------------------------------------------------- #
#
# Covers:
#   - file_header_to_file_ext(file_path)
#   - calculate_dimensions(file_path)
#   - video_duration(file_path)
#
# All methods require real files, so build(:upload, file_ext: ...) is used as
# the host, consistent with spec/logical/file_validator/video_spec.rb.

RSpec.describe FileMethods, type: :model do
  # ----------------------------------------------------------------------- #
  describe "#file_header_to_file_ext" do
    {
      "jpg"  => "sample.jpg",
      "png"  => "sample.png",
      "webp" => "sample.webp",
      "gif"  => "animated.gif",
      "webm" => "animated.webm",
      "mp4"  => "animated.mp4",
    }.each do |expected_ext, fixture_name|
      it "returns '#{expected_ext}' for a #{expected_ext.upcase} file" do
        upload = build(:upload)
        path = file_fixture(fixture_name).to_s
        expect(upload.file_header_to_file_ext(path)).to eq(expected_ext)
      end
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#calculate_dimensions" do
    context "with a JPEG image" do
      it "returns the correct [width, height]" do
        upload = build(:upload, file_ext: "jpg")
        path = file_fixture("sample.jpg").to_s
        expect(upload.calculate_dimensions(path)).to eq([256, 256])
      end
    end

    context "with a PNG image" do
      it "returns the correct [width, height]" do
        upload = build(:upload, file_ext: "png")
        path = file_fixture("sample.png").to_s
        expect(upload.calculate_dimensions(path)).to eq([256, 256])
      end
    end

    context "with a WebP image" do
      it "returns the correct [width, height]" do
        upload = build(:upload, file_ext: "webp")
        path = file_fixture("sample.webp").to_s
        expect(upload.calculate_dimensions(path)).to eq([256, 256])
      end
    end

    context "with an MP4 video" do
      it "returns the correct [width, height]" do
        upload = build(:upload, file_ext: "mp4")
        path = file_fixture("animated.mp4").to_s
        expect(upload.calculate_dimensions(path)).to eq([256, 256])
      end
    end

    context "with a WebM video" do
      it "returns the correct [width, height]" do
        upload = build(:upload, file_ext: "webm")
        path = file_fixture("animated.webm").to_s
        expect(upload.calculate_dimensions(path)).to eq([256, 256])
      end
    end

    context "with a non-image, non-video extension" do
      it "returns [0, 0]" do
        upload = build(:upload, file_ext: "swf")
        expect(upload.calculate_dimensions("/nonexistent/path.swf")).to eq([0, 0])
      end
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#video_duration" do
    context "with an MP4 video" do
      it "returns a positive duration" do
        upload = build(:upload, file_ext: "mp4")
        path = file_fixture("animated.mp4").to_s
        expect(upload.video_duration(path)).to be > 0
      end
    end

    context "with a WebM video" do
      it "returns a positive duration" do
        upload = build(:upload, file_ext: "webm")
        path = file_fixture("animated.webm").to_s
        expect(upload.video_duration(path)).to be > 0
      end
    end

    context "with an animated GIF" do
      it "returns a positive duration" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("animated.gif").to_s
        expect(upload.video_duration(path)).to be > 0
      end
    end

    context "with a static image" do
      it "returns nil" do
        upload = build(:upload, file_ext: "jpg")
        path = file_fixture("sample.jpg").to_s
        expect(upload.video_duration(path)).to be_nil
      end
    end

    context "with a static GIF" do
      it "returns nil" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("static.gif").to_s
        expect(upload.video_duration(path)).to be_nil
      end
    end
  end
end
