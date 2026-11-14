# frozen_string_literal: true

require "rails_helper"

# Expected values match what streamio-ffmpeg reported for the same fixtures,
# so these pin behaviour across its replacement.
RSpec.describe VideoProbe do
  def probe(fixture, file_ext = File.extname(fixture).delete_prefix("."))
    described_class.new(file_fixture(fixture).to_s, file_ext)
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

  describe "a container that understates its duration" do
    include_context "with forged video durations"

    it "reads a WebM's duration from its packets" do
      path = forge_webm_duration("file_validator/animated-vp9.webm", 0.5)
      expect(described_class.new(path, "webm").duration).to be_within(0.01).of(2.0)
    end

    it "reads an MP4's duration from its packets" do
      path = forge_mp4_duration("file_validator/animated-h264-aac.mp4")
      expect(described_class.new(path, "mp4").duration).to be_within(0.01).of(2.04)
    end

    it "scans the packets as the validated type" do
      allow(ExternalCommand).to receive(:run).and_call_original
      probe("file_validator/animated-vp9.webm")
      expect(ExternalCommand).to have_received(:run).with(Danbooru.config.ffprobe_path, "-v", "error", "-protocol_whitelist", "file", "-f", "matroska", "-i", file_fixture("file_validator/animated-vp9.webm").to_s, "-show_entries", "packet=pts_time,duration_time", "-of", "csv=p=0", timeout: anything)
    end
  end

  it "marks a non-media file as invalid" do
    video = probe("staff_file.txt", "webm")
    expect(video).not_to be_valid
    expect(video).to have_attributes(duration: 0, container: nil, video_codec: nil)
    expect(video).not_to have_audio
  end

  it "raises when ffprobe times out" do
    allow(ExternalCommand).to receive(:run).and_raise(ExternalCommand::TimeoutError, "ffprobe timed out after 10 seconds")
    expect { probe("animated.mp4") }.to raise_error(ExternalCommand::TimeoutError)
  end

  it "raises for a missing file" do
    expect { described_class.new("/nonexistent/video.webm", "webm") }.to raise_error(Errno::ENOENT)
  end

  it "only reads the file as its validated type" do
    allow(ExternalCommand).to receive(:run).and_call_original
    probe("animated.mp4")
    expect(ExternalCommand).to have_received(:run).with(Danbooru.config.ffprobe_path, "-protocol_whitelist", "file", "-f", "mov", "-i", file_fixture("animated.mp4").to_s, any_args, timeout: anything)
  end

  # An HLS playlist makes ffmpeg open the files it lists, so it must not be read as one.
  # The .m3u8 name is what lets ffmpeg's own probing pick HLS without a forced demuxer.
  it "does not follow a playlist passed off as a video" do
    playlist = Tempfile.new(["playlist", ".m3u8"])
    playlist.write("#EXTM3U\n#EXT-X-TARGETDURATION:2\n#EXTINF:2,\n#{file_fixture('animated.mp4')}\n#EXT-X-ENDLIST\n")
    playlist.close

    video = described_class.new(playlist.path, "webm")
    expect(video).not_to be_valid
    expect(video.container).not_to eq("hls")
  ensure
    playlist&.close!
  end
end
