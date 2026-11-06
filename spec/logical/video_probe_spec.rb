# frozen_string_literal: true

require "rails_helper"

# Expected values match what streamio-ffmpeg reported for the same fixtures,
# so these pin behaviour across its replacement.
RSpec.describe VideoProbe do
  def probe(fixture)
    described_class.new(file_fixture(fixture).to_s)
  end

  describe "a VP9 WebM" do
    subject(:video) { probe("file_validator/animated-vp9.webm") }

    it "reads container and stream metadata" do
      expect(video).to be_valid
      expect(video).to have_attributes(
        container: "matroska,webm",
        video_codec: "vp9",
        audio_codec: nil,
        colorspace: "yuv420p",
        width: 256,
        height: 256,
        frame_rate: Rational(3, 1),
        duration: 2.0,
        size: File.size(file_fixture("file_validator/animated-vp9.webm")),
      )
      expect(video).not_to have_audio
    end
  end

  describe "an H.264 MP4 with AAC audio" do
    subject(:video) { probe("file_validator/animated-h264-aac.mp4") }

    it "reads the audio stream" do
      expect(video).to be_valid
      expect(video).to have_attributes(container: "mov,mp4,m4a,3gp,3g2,mj2", video_codec: "h264", audio_codec: "aac", frame_rate: Rational(25, 1))
      expect(video).to have_audio
    end
  end

  it "reports the pixel format as the colorspace" do
    expect(probe("file_validator/animated-yuv444p.webm").colorspace).to eq("yuv444p")
  end

  it "reads the sample aspect ratio" do
    expect(probe("file_validator/animated-anamorphic.mp4").sar).not_to eq("1:1")
  end

  it "reads the duration of an animated GIF" do
    expect(probe("animated.gif").duration).to be_within(0.01).of(1.98)
  end

  it "marks a non-media file as invalid" do
    video = probe("staff_file.txt")
    expect(video).not_to be_valid
    expect(video).to have_attributes(duration: 0, container: nil, video_codec: nil)
    expect(video).not_to have_audio
  end

  it "raises for a missing file" do
    expect { described_class.new("/nonexistent/video.webm") }.to raise_error(Errno::ENOENT)
  end
end
