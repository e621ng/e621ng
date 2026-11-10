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
        args = described_class.video_alpha_decoder_args(file_fixture("animated-transparent-vp8.webm").to_s, "webm")
        expect(args).to eq(["-vcodec", "libvpx"])
      end
    end

    context "with a VP9 WebM that has alpha" do
      it "selects the libvpx-vp9 decoder" do
        args = described_class.video_alpha_decoder_args(file_fixture("animated-transparent-vp9.webm").to_s, "webm")
        expect(args).to eq(["-vcodec", "libvpx-vp9"])
      end
    end

    context "with a video that has no alpha channel" do
      it "returns no extra decoder args" do
        args = described_class.video_alpha_decoder_args(file_fixture("animated.mp4").to_s, "mp4")
        expect(args).to eq([])
      end
    end

    context "when ffprobe exits non-zero" do
      it "returns no extra decoder args" do
        fake_status = instance_double(Process::Status)
        allow(fake_status).to receive(:==).with(0).and_return(false)
        allow(ExternalCommand).to receive(:run).and_return([+"", +"boom", fake_status])

        args = described_class.video_alpha_decoder_args(file_fixture("animated-transparent-vp9.webm").to_s, "webm")
        expect(args).to eq([])
      end
    end
  end

  # -------------------------------------------------------------------------
  # .with_still_image
  #
  # End-to-end: decoding a transparent WebM into a snapshot must preserve the
  # alpha plane, otherwise the generated thumbnails get an opaque background.
  # -------------------------------------------------------------------------
  describe ".with_still_image" do
    shared_examples "a transparent video snapshot" do |fixture|
      # The snapshot is deleted after the block, so inspect it inside.
      let(:snapshot) do
        described_class.with_still_image(file_fixture(fixture).to_s, file_ext: "webm") do |path|
          { dimensions: image_dimensions(path), bands: image_bands(path), alpha_range: band_range(path, 3) }
        end
      end

      it "produces an image" do
        expect(snapshot[:dimensions]).to all(be_positive)
      end

      it "preserves the alpha channel" do
        expect(snapshot[:bands]).to eq(4)
      end

      it "contains fully transparent pixels" do
        # All frames of the fixture are partially transparent, so the alpha
        # band must reach 0 somewhere. A value > 0 would mean alpha was dropped.
        expect(snapshot[:alpha_range].first).to eq(0)
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
