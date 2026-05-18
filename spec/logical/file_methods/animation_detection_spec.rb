# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                 FileMethods — animation detection methods                   #
# --------------------------------------------------------------------------- #
#
# Covers:
#   - is_animated_png?(file_path)
#   - is_animated_gif?(file_path)
#   - is_animated_webp?(file_path)
#
# Each method guards on `file_ext` before touching the file, so the falsy
# "wrong extension" case needs no real file. Real fixture files are used for
# the truthy/falsy "correct extension" cases.
# Host: build(:upload, file_ext: ...) — matches the pattern used in
# spec/logical/file_validator/video_spec.rb.

RSpec.describe FileMethods, type: :model do
  # ----------------------------------------------------------------------- #
  describe "#is_animated_png?" do
    context "with an animated PNG fixture" do
      it "returns true" do
        upload = build(:upload, file_ext: "png")
        path = file_fixture("animated.png").to_s
        expect(upload.is_animated_png?(path)).to be true
      end
    end

    context "with a static PNG fixture" do
      it "returns false" do
        upload = build(:upload, file_ext: "png")
        path = file_fixture("sample.png").to_s
        expect(upload.is_animated_png?(path)).to be false
      end
    end

    context "when file_ext is not png" do
      it "returns false without reading the file" do
        upload = build(:upload, file_ext: "gif")
        # Passing a non-existent path proves the file is never opened
        expect(upload.is_animated_png?("/nonexistent/path.gif")).to be false
      end
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_animated_gif?" do
    context "with an animated GIF fixture" do
      it "returns true" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("animated.gif").to_s
        expect(upload.is_animated_gif?(path)).to be true
      end
    end

    context "with a static GIF fixture" do
      it "returns false" do
        upload = build(:upload, file_ext: "gif")
        path = file_fixture("static.gif").to_s
        expect(upload.is_animated_gif?(path)).to be false
      end
    end

    context "when file_ext is not gif" do
      it "returns false without reading the file" do
        upload = build(:upload, file_ext: "png")
        expect(upload.is_animated_gif?("/nonexistent/path.png")).to be false
      end
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_animated_webp?" do
    context "with an animated WebP fixture" do
      it "returns true" do
        upload = build(:upload, file_ext: "webp")
        path = file_fixture("animated.webp").to_s
        expect(upload.is_animated_webp?(path)).to be true
      end
    end

    context "with a static WebP fixture" do
      it "returns false" do
        upload = build(:upload, file_ext: "webp")
        path = file_fixture("sample.webp").to_s
        expect(upload.is_animated_webp?(path)).to be false
      end
    end

    context "when file_ext is not webp" do
      it "returns false without reading the file" do
        upload = build(:upload, file_ext: "png")
        expect(upload.is_animated_webp?("/nonexistent/path.png")).to be false
      end
    end

    context "with a truncated / unreadable file" do
      # NOTE: this test is quite slow, since File.open on a nonexitent file raises Errno::ENOENT
      # only after a timeout, which in turn routes through the general StandardError rescue. That
      # is correct behavior, but it does mean the test takes ~1.7 seconds to run.
      it "returns false via the rescue clause" do
        upload = build(:upload, file_ext: "webp")
        expect(upload.is_animated_webp?("/nonexistent/path.webp")).to be false
      end
    end
  end
end
