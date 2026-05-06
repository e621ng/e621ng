# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVideoConversionJob do
  include_context "as admin"

  # Default post: a webm large enough to trigger 480p sample generation.
  # smaller_dim = 720 → 720p skipped (not > 720), 480p generated (720 > 530).
  let(:post) { create(:post, file_ext: "webm", image_width: 1280, image_height: 720) }
  let(:storage) { instance_spy(StorageManager) }

  let(:ok_status) do
    instance_double(Process::Status).tap { |s| allow(s).to receive(:==).with(0).and_return(true) }
  end

  # Represents the original video file as reported by ffmpeg-ruby.
  let(:original_movie) do
    instance_double(FFMPEG::Movie,
                    valid?: true,
                    video_codec: "vp9",
                    frame_rate: 24.0,
                    width: 1280,
                    height: 720)
  end

  # Returned for all transcoded sample files (non-original paths).
  let(:sample_movie) do
    instance_double(FFMPEG::Movie,
                    valid?: true,
                    video_codec: "h264",
                    frame_rate: 24.0,
                    width: 640,
                    height: 360,
                    size: 10_000)
  end

  def perform(id = post.id)
    described_class.perform_now(id)
  end

  def job_instance
    described_class.new
  end

  # Stubs FFMPEG, Open3, and StorageManager so no real transcoding or I/O occurs.
  #
  # IMPORTANT: Call this AFTER `post` has been created. Creating the post first
  # ensures the factory's after_create callbacks (e.g. check_for_ai_content) use
  # real storage — avoiding conflicts with the StorageManager spy.
  #
  # Post.find is stubbed to return the same `post` instance so that the memoized
  # file_path (set during factory creation) is preserved inside perform.
  def stub_ffmpeg_and_storage
    allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
    allow(Post).to receive(:find).with(post.id).and_return(post)
    allow(FFMPEG::Movie).to receive(:new).and_return(sample_movie)
    allow(FFMPEG::Movie).to receive(:new).with(post.file_path).and_return(original_movie)
    allow(Open3).to receive(:capture3).and_return(["", "", ok_status])
  end

  describe "#perform" do
    context "when the post is not a video" do
      let(:post) { create(:post, file_ext: "jpg") }

      it "returns early without modifying video_samples" do
        original_samples = post.video_samples
        perform
        expect(post.reload.video_samples).to eq(original_samples)
      end
    end

    context "when the post does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { perform(0) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "with a valid video post" do
      before do
        post  # Force eager creation before mocks so callbacks use real storage
        stub_ffmpeg_and_storage
      end

      it "calls delete_video_samples! before processing" do
        allow(post).to receive(:delete_video_samples!).and_call_original
        perform
        expect(post).to have_received(:delete_video_samples!)
      end

      it "raises when the original file is reported invalid by ffmpeg" do
        allow(original_movie).to receive(:valid?).and_return(false)
        expect { perform }.to raise_error(RuntimeError, /Invalid video file/)
      end

      it "raises when ffmpeg transcoding exits with a non-zero status" do
        bad_status = instance_double(Process::Status)
        allow(bad_status).to receive(:==).with(0).and_return(false)
        allow(Open3).to receive(:capture3).and_return(["stdout output", "stderr output", bad_status])
        expect { perform }.to raise_error(StandardError, /unable to transcode files/)
      end

      it "updates video_samples with the original codec and fps" do
        perform
        samples = post.reload.video_samples
        expect(samples["original"]["codec"]).to eq("vp9")
        expect(samples["original"]["fps"]).to eq(24.0)
      end

      it "populates variants for a non-h264 video" do
        perform
        expect(post.reload.video_samples["variants"]).not_to be_empty
      end
    end

    context "with an h264 mp4 post" do
      let(:post) { create(:post, file_ext: "mp4", image_width: 1280, image_height: 720) }
      let(:original_movie) do
        instance_double(FFMPEG::Movie,
                        valid?: true,
                        video_codec: "h264",
                        frame_rate: 24.0,
                        width: 1280,
                        height: 720)
      end

      before do
        post  # Force eager creation before mocks
        allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
        allow(Post).to receive(:find).with(post.id).and_return(post)
        allow(FFMPEG::Movie).to receive(:new).and_return(sample_movie)
        allow(FFMPEG::Movie).to receive(:new).with(post.file_path).and_return(original_movie)
        allow(Open3).to receive(:capture3).and_return(["", "", ok_status])
      end

      it "does not generate an mp4 variant" do
        perform
        expect(post.reload.video_samples["variants"]).to be_empty
      end

      it "formats h264 codec as the browser-compatible string in video_samples" do
        perform
        expect(post.reload.video_samples["original"]["codec"]).to eq("avc1.4D401E")
      end
    end
  end

  describe "#generate_samples" do
    let(:job) { job_instance }

    let(:fake_tempfile) { Tempfile.new("test-video") }

    before { allow(job).to receive(:generate_mp4_video).and_return(fake_tempfile) }

    after { fake_tempfile.close! rescue nil } # rubocop:disable Style/RescueModifier

    def make_original(codec:, frame_rate:)
      instance_double(FFMPEG::Movie, video_codec: codec, frame_rate: frame_rate)
    end

    context "when the codec is not h264" do
      let(:original) { make_original(codec: "vp9", frame_rate: 24.0) }

      it "generates an mp4 variant" do
        result = job.generate_samples(post, original)
        expect(result[:variants]).to have_key(:mp4)
      end
    end

    context "when the codec is h264" do
      let(:post) { create(:post, file_ext: "mp4", image_width: 1280, image_height: 720) }
      let(:original) { make_original(codec: "h264", frame_rate: 24.0) }

      it "does not generate a variant" do
        result = job.generate_samples(post, original)
        expect(result[:variants]).to be_empty
      end
    end

    context "when smaller_dim is significantly larger than the 720p clamp" do
      # smaller_dim = 900; 900 > 720 (clamp) and 900 > 770 (clamp + 50)
      let(:post) { create(:post, file_ext: "webm", image_width: 1280, image_height: 900) }
      let(:original) { make_original(codec: "vp9", frame_rate: 24.0) }

      it "generates a 720p sample" do
        result = job.generate_samples(post, original)
        expect(result[:samples]).to have_key(:"720p")
      end
    end

    context "when smaller_dim is at or below the 480p clamp" do
      # smaller_dim = 480; skipped by: next if smaller_dim <= 480
      let(:post) { create(:post, file_ext: "webm", image_width: 640, image_height: 480) }
      let(:original) { make_original(codec: "vp9", frame_rate: 24.0) }

      it "does not generate any samples" do
        result = job.generate_samples(post, original)
        expect(result[:samples]).to be_empty
      end
    end

    context "when smaller_dim is in the 720p gray zone (clamp < smaller_dim <= clamp + 50)" do
      # smaller_dim = 740; 720 < 740 <= 770
      let(:post) { create(:post, file_ext: "webm", image_width: 1280, image_height: 740) }

      context "with a frame rate at or below 30" do
        let(:original) { make_original(codec: "vp9", frame_rate: 24.0) }

        it "does not generate a 720p sample" do
          result = job.generate_samples(post, original)
          expect(result[:samples]).not_to have_key(:"720p")
        end
      end

      context "with a frame rate above 30" do
        let(:original) { make_original(codec: "vp9", frame_rate: 60.0) }

        it "generates a 720p sample" do
          result = job.generate_samples(post, original)
          expect(result[:samples]).to have_key(:"720p")
        end
      end

      context "with a zero frame rate (variable frame rate detection)" do
        let(:original) { make_original(codec: "vp9", frame_rate: 0) }

        it "generates a 720p sample" do
          result = job.generate_samples(post, original)
          expect(result[:samples]).to have_key(:"720p")
        end
      end
    end
  end

  describe "#calculate_scale" do
    subject(:job) { job_instance }

    def scale(width, height, clamp)
      p = build(:post, image_width: width, image_height: height)
      job.calculate_scale(p, clamp)
    end

    it "returns equal dimensions for a square video" do
      expect(scale(720, 720, 720)).to eq("720:720")
    end

    it "clamps height for a standard landscape video" do
      # ratio = 720/720 = 1, 1280*1 = 1280, not > 1440 → "-2:720"
      expect(scale(1280, 720, 720)).to eq("-2:720")
    end

    it "clamps width for a very wide landscape video" do
      # ratio = 720/720 = 1, 1500*1 = 1500 > 1440 → "1440:-2"
      expect(scale(1500, 720, 720)).to eq("1440:-2")
    end

    it "clamps width for a standard portrait video" do
      # ratio = 720/720 = 1, 1280*1 = 1280, not > 1440 → "720:-2"
      expect(scale(720, 1280, 720)).to eq("720:-2")
    end

    it "clamps height for a very tall portrait video" do
      # ratio = 1440/720 = 2, 3000*2 = 6000 > 1440 → "-2:1440"
      expect(scale(1440, 3000, 720)).to eq("-2:1440")
    end
  end

  describe "#round_two_two" do
    subject(:job) { job_instance }

    it "returns an already-even number unchanged" do
      expect(job.round_two_two(720)).to eq(720)
    end

    it "rounds down for a number one above an even" do
      # (721 / 2) = 360 (integer division), 360 * 2 = 720
      expect(job.round_two_two(721)).to eq(720)
    end

    it "rounds down for an odd number below an even" do
      # (719 / 2) = 359, 359 * 2 = 718
      expect(job.round_two_two(719)).to eq(718)
    end

    it "rounds 1 to 0" do
      expect(job.round_two_two(1)).to eq(0)
    end

    it "rounds 1081 to 1080" do
      expect(job.round_two_two(1081)).to eq(1080)
    end
  end

  describe "#format_codec_name" do
    subject(:job) { job_instance }

    it "converts h264 to the browser-compatible codec string" do
      expect(job.format_codec_name("h264")).to eq("avc1.4D401E")
    end

    it "converts av1 to the browser-compatible codec string" do
      expect(job.format_codec_name("av1")).to eq("av01.0.00M.08")
    end

    it "passes through an unknown codec name unchanged" do
      expect(job.format_codec_name("vp9")).to eq("vp9")
    end

    it "passes through vp8 unchanged" do
      expect(job.format_codec_name("vp8")).to eq("vp8")
    end
  end

  describe "#generate_metadata" do
    subject(:job) { job_instance }

    let(:fake_file) { instance_spy(Tempfile, path: "/tmp/fake_video.mp4") }
    let(:movie) do
      instance_double(FFMPEG::Movie,
                      valid?: true,
                      video_codec: "h264",
                      frame_rate: 24.0,
                      width: 640,
                      height: 360,
                      size: 5_000)
    end

    before { allow(FFMPEG::Movie).to receive(:new).with(fake_file.path).and_return(movie) }

    it "returns a metadata hash for a valid video" do
      result = job.generate_metadata({ sample: fake_file })
      expect(result[:sample]).to include(width: 640, height: 360, fps: 24.0, size: 5_000)
    end

    it "formats the codec name in the returned metadata" do
      result = job.generate_metadata({ sample: fake_file })
      expect(result[:sample][:codec]).to eq("avc1.4D401E")
    end

    it "returns nil for an invalid video file" do
      allow(movie).to receive(:valid?).and_return(false)
      result = job.generate_metadata({ sample: fake_file })
      expect(result[:sample]).to be_nil
    end

    it "closes the file after successful processing" do
      job.generate_metadata({ sample: fake_file })
      expect(fake_file).to have_received(:close!)
    end

    it "closes the file even when the video is invalid" do
      allow(movie).to receive(:valid?).and_return(false)
      job.generate_metadata({ sample: fake_file })
      expect(fake_file).to have_received(:close!)
    end
  end

  describe "#move_videos" do
    subject(:job) { job_instance }

    let(:variant_file) { instance_spy(Tempfile) }
    let(:sample_file) { instance_spy(Tempfile) }

    before do
      post # Force eager creation before storage mock so callbacks use real storage
      allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
    end

    it "stores variant files with scale 'alt'" do
      job.move_videos(post, { variants: { mp4: variant_file }, samples: {} })
      expect(storage).to have_received(:file_path).with(post.md5, "mp4", :scaled, protect: anything, scale: "alt")
    end

    it "stores sample files using the sample name as the scale" do
      job.move_videos(post, { variants: {}, samples: { "720p": sample_file } })
      expect(storage).to have_received(:file_path).with(post.md5, "mp4", :scaled, protect: anything, scale: "720p")
    end

    it "calls store for each generated file" do
      job.move_videos(post, { variants: { mp4: variant_file }, samples: { "720p": sample_file } })
      expect(storage).to have_received(:store).twice
    end
  end
end
