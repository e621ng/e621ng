# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  # -------------------------------------------------------------------------
  # .video_snapshot_filter
  #
  # Some files are mistagged with an exotic YCbCr matrix (e.g. ICtCp, which
  # cannot legitimately pair with 8-bit yuv420p). swscale can't convert from
  # it and aborts the thumbnail filter graph, so we relabel the matrix to
  # bt709 for those files only.
  # -------------------------------------------------------------------------
  describe ".video_snapshot_filter" do
    let(:scale) { "scale='min(iw,1700)':'min(ih,1700)':force_original_aspect_ratio=decrease:flags=lanczos" }

    context "with a normally tagged video" do
      it "shrinks frames to the largest sample size before picking one" do
        expect(described_class.video_snapshot_filter(file_fixture("animated.mp4").to_s)).to eq("#{scale},thumbnail")
      end
    end

    context "with a video tagged with an unsupported colour space" do
      it "relabels the matrix to bt709" do
        expect(described_class.video_snapshot_filter(file_fixture("mislabeled-ictcp.mp4").to_s)).to eq("setparams=colorspace=bt709,#{scale},thumbnail")
      end
    end

    context "when ffprobe exits non-zero" do
      it "falls back to the scale and thumbnail filters" do
        fake_status = instance_double(Process::Status)
        allow(fake_status).to receive(:==).with(0).and_return(false)
        allow(ExternalCommand).to receive(:run).and_return([+"", +"boom", fake_status])

        expect(described_class.video_snapshot_filter(file_fixture("mislabeled-ictcp.mp4").to_s)).to eq("#{scale},thumbnail")
      end
    end
  end

  # -------------------------------------------------------------------------
  # .colorspace_relabel_filter
  #
  # Shared with PostVideoConversionJob, whose `scale` filter fails on the
  # same mistagged colour spaces as the snapshot path.
  # -------------------------------------------------------------------------
  describe ".colorspace_relabel_filter" do
    it "returns nil for a normally tagged video" do
      expect(described_class.colorspace_relabel_filter(file_fixture("animated.mp4").to_s)).to be_nil
    end

    it "returns a setparams filter for an unsupported colour space" do
      expect(described_class.colorspace_relabel_filter(file_fixture("mislabeled-ictcp.mp4").to_s)).to eq("setparams=colorspace=bt709")
    end
  end

  # -------------------------------------------------------------------------
  # .with_still_image
  #
  # End-to-end regression: without the colour-space relabel, ffmpeg aborts
  # with "Impossible to convert between the formats" and no snapshot is
  # produced, surfacing as "Could not generate video snapshot".
  # -------------------------------------------------------------------------
  describe ".with_still_image" do
    context "with a video mistagged as ICtCp" do
      it "still generates a snapshot" do
        width = described_class.with_still_image(file_fixture("mislabeled-ictcp.mp4").to_s, is_video: true) { |path| image_dimensions(path).first }
        expect(width).to eq(64)
      end
    end
  end
end
