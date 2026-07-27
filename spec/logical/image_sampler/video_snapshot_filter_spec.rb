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
    context "with a normally tagged video" do
      it "uses the plain thumbnail filter" do
        expect(described_class.video_snapshot_filter(file_fixture("animated.mp4").to_s)).to eq("thumbnail")
      end
    end

    context "with a video tagged with an unsupported colour space" do
      it "relabels the matrix to bt709" do
        expect(described_class.video_snapshot_filter(file_fixture("mislabeled-ictcp.mp4").to_s)).to eq("setparams=colorspace=bt709,thumbnail")
      end
    end

    context "when ffprobe exits non-zero" do
      it "falls back to the plain thumbnail filter" do
        fake_status = instance_double(Process::Status)
        allow(fake_status).to receive(:==).with(0).and_return(false)
        allow(Open3).to receive(:capture3).and_return([+"", +"boom", fake_status])

        expect(described_class.video_snapshot_filter(file_fixture("mislabeled-ictcp.mp4").to_s)).to eq("thumbnail")
      end
    end
  end

  # -------------------------------------------------------------------------
  # .image_from_path
  #
  # End-to-end regression: without the colour-space relabel, ffmpeg aborts
  # with "Impossible to convert between the formats" and no snapshot is
  # produced, surfacing as "Could not generate video snapshot".
  # -------------------------------------------------------------------------
  describe ".image_from_path" do
    context "with a video mistagged as ICtCp" do
      it "still generates a snapshot" do
        image = described_class.image_from_path(file_fixture("mislabeled-ictcp.mp4").to_s, is_video: true)
        expect(image).to be_a(Vips::Image)
      end
    end
  end
end
