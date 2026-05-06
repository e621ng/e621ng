# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   FileMethods — type detection methods                      #
# --------------------------------------------------------------------------- #
#
# Covers:
#   - is_png?, is_jpg?, is_gif?, is_flash?, is_webm?, is_mp4?, is_webp?
#   - is_image?  (png | jpg | gif | webp)
#   - is_video?  (webm | mp4)
#
# These methods only inspect the `file_ext` attribute, so an anonymous class
# that includes FileMethods is sufficient — no database or fixture files needed.

RSpec.describe FileMethods do
  # Anonymous host class: mimics the minimum interface required by FileMethods.
  let(:host_class) do
    Class.new do
      include FileMethods
      attr_accessor :file_ext
    end
  end

  let(:host) { host_class.new }

  # ----------------------------------------------------------------------- #
  describe "#is_png?" do
    it "returns true when file_ext is 'png'" do
      host.file_ext = "png"
      expect(host.is_png?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "jpg"
      expect(host.is_png?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_jpg?" do
    it "returns true when file_ext is 'jpg'" do
      host.file_ext = "jpg"
      expect(host.is_jpg?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "png"
      expect(host.is_jpg?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_gif?" do
    it "returns true when file_ext is 'gif'" do
      host.file_ext = "gif"
      expect(host.is_gif?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "png"
      expect(host.is_gif?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_flash?" do
    it "returns true when file_ext is 'swf'" do
      host.file_ext = "swf"
      expect(host.is_flash?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "mp4"
      expect(host.is_flash?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_webm?" do
    it "returns true when file_ext is 'webm'" do
      host.file_ext = "webm"
      expect(host.is_webm?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "mp4"
      expect(host.is_webm?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_mp4?" do
    it "returns true when file_ext is 'mp4'" do
      host.file_ext = "mp4"
      expect(host.is_mp4?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "webm"
      expect(host.is_mp4?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_webp?" do
    it "returns true when file_ext is 'webp'" do
      host.file_ext = "webp"
      expect(host.is_webp?).to be true
    end

    it "returns false for other extensions" do
      host.file_ext = "png"
      expect(host.is_webp?).to be false
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_image?" do
    %w[png jpg gif webp].each do |ext|
      it "returns true for '#{ext}'" do
        host.file_ext = ext
        expect(host.is_image?).to be true
      end
    end

    %w[webm mp4 swf].each do |ext|
      it "returns false for '#{ext}'" do
        host.file_ext = ext
        expect(host.is_image?).to be false
      end
    end
  end

  # ----------------------------------------------------------------------- #
  describe "#is_video?" do
    %w[webm mp4].each do |ext|
      it "returns true for '#{ext}'" do
        host.file_ext = ext
        expect(host.is_video?).to be true
      end
    end

    %w[png jpg gif webp swf].each do |ext|
      it "returns false for '#{ext}'" do
        host.file_ext = ext
        expect(host.is_video?).to be false
      end
    end
  end
end
