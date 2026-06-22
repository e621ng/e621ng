# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  # -------------------------------------------------------------------------
  # .video_alpha_decoder_args
  #
  # Both VP8 and VP9 store alpha as a secondary bitstream tagged
  # alpha_mode=1. The native FFmpeg decoders ignore it, so these args force
  # the libvpx decoders that actually decode the alpha plane.
  # -------------------------------------------------------------------------
  describe ".video_alpha_decoder_args" do
    context "with a VP8 WebM that has alpha" do
      it "selects the libvpx decoder" do
        args = described_class.video_alpha_decoder_args(file_fixture("animated-transparent-vp8.webm").to_s)
        expect(args).to eq(["-vcodec", "libvpx"])
      end
    end

    context "with a VP9 WebM that has alpha" do
      it "selects the libvpx-vp9 decoder" do
        args = described_class.video_alpha_decoder_args(file_fixture("animated-transparent-vp9.webm").to_s)
        expect(args).to eq(["-vcodec", "libvpx-vp9"])
      end
    end

    context "with a video that has no alpha channel" do
      it "returns no extra decoder args" do
        args = described_class.video_alpha_decoder_args(file_fixture("animated.mp4").to_s)
        expect(args).to eq([])
      end
    end

    context "when ffprobe exits non-zero" do
      it "returns no extra decoder args" do
        fake_status = instance_double(Process::Status)
        allow(fake_status).to receive(:==).with(0).and_return(false)
        allow(Open3).to receive(:capture3).and_return([+"", +"boom", fake_status])

        args = described_class.video_alpha_decoder_args(file_fixture("animated-transparent-vp9.webm").to_s)
        expect(args).to eq([])
      end
    end
  end

  # -------------------------------------------------------------------------
  # .image_from_path
  #
  # End-to-end: decoding a transparent WebM into a snapshot must preserve the
  # alpha plane, otherwise the generated thumbnails get an opaque background.
  # -------------------------------------------------------------------------
  describe ".image_from_path" do
    shared_examples "a transparent video snapshot" do |fixture|
      let(:image) { described_class.image_from_path(file_fixture(fixture).to_s, is_video: true) }

      it "returns a Vips::Image" do
        expect(image).to be_a(Vips::Image)
      end

      it "preserves the alpha channel" do
        expect(image.bands).to eq(4)
      end

      it "contains fully transparent pixels" do
        # All frames of the fixture are partially transparent, so the alpha
        # band must reach 0 somewhere. A value > 0 would mean alpha was dropped.
        expect(image[3].min).to eq(0)
      end
    end

    context "with a transparent VP8 WebM" do
      include_examples "a transparent video snapshot", "animated-transparent-vp8.webm"
    end

    context "with a transparent VP9 WebM" do
      include_examples "a transparent video snapshot", "animated-transparent-vp9.webm"
    end
  end
end
