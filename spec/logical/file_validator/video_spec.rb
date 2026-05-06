# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#              FileValidator — video validation methods                       #
# --------------------------------------------------------------------------- #
#
# Covers:
#   - validate_container_format  (container + video codec rules)
#   - validate_audio_codec       (AV1-only audio codec restriction)
#   - validate_duration          (max video length)
#   - validate_colorspace        (must be yuv420p)
#   - validate_sar               (non-anamorphic)
#
# Real fixture files under spec/fixtures/files/file_validator/ are used where
# a matching fixture exists. instance_double is used for edge cases that have
# no corresponding fixture (e.g. duration over the limit, VP8 with audio).

RSpec.describe FileValidator, type: :model do
  # Helper to build a validator backed by a real Upload + real file path.
  def validator_for_fixture(fixture_path, file_ext:)
    upload = build(:upload, file_ext: file_ext)
    path   = file_fixture(fixture_path).to_s
    [FileValidator.new(upload, path), upload.video(path)]
  end

  # Helper to build a validator backed by a fake FFMPEG::Movie double.
  def validator_with_video_double(file_ext: "webm", **video_attrs)
    upload = build(:upload, file_ext: file_ext)
    video  = instance_double(FFMPEG::Movie, { valid?: true }.merge(video_attrs))
    [FileValidator.new(upload, ""), upload, video]
  end

  # ------------------------------------------------------------------ #
  describe "#validate_container_format" do
    context "with a VP8 WebM" do
      it "is valid" do
        v, video = validator_for_fixture("file_validator/animated-vp8.webm", file_ext: "webm")
        v.validate_container_format(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with a VP9 WebM" do
      it "is valid" do
        v, video = validator_for_fixture("file_validator/animated-vp9.webm", file_ext: "webm")
        v.validate_container_format(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with an AV1 MP4" do
      it "is valid" do
        v, video = validator_for_fixture("file_validator/animated-av1-opus.mp4", file_ext: "mp4")
        v.validate_container_format(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with an H.264 MP4 (not yet allowed)" do
      it "adds an error" do
        v, video = validator_for_fixture("file_validator/animated-h264.mp4", file_ext: "mp4")
        v.validate_container_format(video)
        expect(v.record.errors[:base]).to include(include("video must be WebM with VP8/VP9 or MP4 with AV1"))
      end
    end

    context "with an AV1 WebM (wrong container for AV1)" do
      it "adds an error" do
        v, video = validator_for_fixture("file_validator/animated-av1.webm", file_ext: "webm")
        v.validate_container_format(video)
        expect(v.record.errors[:base]).to include(include("video must be WebM with VP8/VP9 or MP4 with AV1"))
      end
    end

    context "with an invalid video" do
      it "adds a 'video isn't valid' error" do
        v, _upload, video = validator_with_video_double(valid?: false)
        v.validate_container_format(video)
        expect(v.record.errors[:base]).to include("video isn't valid")
      end
    end
  end

  # ------------------------------------------------------------------ #
  describe "#validate_audio_codec" do
    context "with AV1 + Opus audio" do
      it "is valid" do
        v, video = validator_for_fixture("file_validator/animated-av1-opus.mp4", file_ext: "mp4")
        v.validate_audio_codec(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with AV1 + FLAC audio (not allowed)" do
      it "adds an error" do
        v, video = validator_for_fixture("file_validator/animated-av1-flac.mp4", file_ext: "mp4")
        v.validate_audio_codec(video)
        expect(v.record.errors[:base]).to include(include("video uses AV1 and must use Opus, AAC, or MP3 audio codec"))
      end
    end

    context "with AV1 + no audio track" do
      it "is valid" do
        v, _upload, video = validator_with_video_double(file_ext: "mp4", video_codec: "av1", audio_codec: nil)
        v.validate_audio_codec(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with VP8 (non-AV1) regardless of audio codec" do
      it "is valid because the restriction only applies to AV1" do
        v, _upload, video = validator_with_video_double(file_ext: "webm", video_codec: "vp8", audio_codec: "vorbis")
        v.validate_audio_codec(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end
  end

  # ------------------------------------------------------------------ #
  describe "#validate_duration" do
    context "when the video is within the duration limit" do
      it "is valid" do
        v, video = validator_for_fixture("file_validator/animated-vp8.webm", file_ext: "webm")
        v.validate_duration(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "when the video exceeds the duration limit" do
      it "adds an error" do
        max = Danbooru.config.max_video_duration
        v, _upload, video = validator_with_video_double(duration: max + 1)
        v.validate_duration(video)
        expect(v.record.errors[:base]).to include(include("video must not be longer than #{max} seconds"))
      end
    end
  end

  # ------------------------------------------------------------------ #
  describe "#validate_colorspace" do
    context "with yuv420p colorspace" do
      it "is valid" do
        v, video = validator_for_fixture("file_validator/animated-vp8.webm", file_ext: "webm")
        v.validate_colorspace(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with yuv444p colorspace" do
      it "adds an error" do
        v, video = validator_for_fixture("file_validator/animated-yuv444p.webm", file_ext: "webm")
        v.validate_colorspace(video)
        expect(v.record.errors[:base]).to include(include("video colorspace must be yuv420p"))
      end
    end
  end

  # ------------------------------------------------------------------ #
  describe "#validate_sar" do
    context "with an anamorphic video (non-1:1 SAR)" do
      it "adds an error" do
        v, video = validator_for_fixture("file_validator/animated-anamorphic.mp4", file_ext: "mp4")
        v.validate_sar(video)
        expect(v.record.errors[:base]).to include(include("video is anamorphic"))
      end
    end

    context "with a 1:1 SAR" do
      it "is valid" do
        v, _upload, video = validator_with_video_double(sar: "1:1")
        v.validate_sar(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end

    context "with no SAR metadata" do
      it "is valid" do
        v, _upload, video = validator_with_video_double(sar: nil)
        v.validate_sar(video)
        expect(v.record.errors[:base]).to be_empty
      end
    end
  end
end
