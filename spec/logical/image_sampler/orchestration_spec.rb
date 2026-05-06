# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  let(:sm) { instance_double(StorageManager::Local) }

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      storage_manager: sm,
      large_image_width: 850,
      small_image_width: 256,
    )
    allow(sm).to receive(:post_file_path).and_return("/tmp/fake/path.jpg")
    allow(sm).to receive(:store)
  end

  # -------------------------------------------------------------------------
  # .generate_post_images
  # -------------------------------------------------------------------------
  describe ".generate_post_images" do
    let(:file_path) { file_fixture("sample.jpg").to_s }
    let(:post) do
      instance_double(
        Post,
        file_path:         file_path,
        is_flash?:         false,
        is_video?:         false,
        is_gif?:           false,
        is_animated_png?:  false,
        is_animated_webp?: false,
        image_width:       256,
        image_height:      256,
        bg_color:          "000000",
      )
    end

    # Helper: stub thumbnail and sample to return fake Tempfile doubles so we
    # can count store calls without performing real image processing.
    def stub_thumbnail
      fake = { jpg: instance_double(Tempfile, close!: nil), webp: instance_double(Tempfile, close!: nil) }
      allow(described_class).to receive(:thumbnail).and_return(fake)
      fake
    end

    def stub_sample
      fake = { jpg: instance_double(Tempfile, close!: nil), webp: instance_double(Tempfile, close!: nil) }
      allow(described_class).to receive(:sample).and_return(fake)
      fake
    end

    context "when the file does not exist" do
      it "returns without calling StorageManager" do
        allow(File).to receive(:exist?).with(file_path).and_return(false)
        described_class.generate_post_images(post)
        expect(sm).not_to have_received(:store)
      end
    end

    context "when the post is a flash file" do
      it "returns without calling StorageManager" do
        allow(post).to receive(:is_flash?).and_return(true)
        described_class.generate_post_images(post)
        expect(sm).not_to have_received(:store)
      end
    end

    context "when the post is an animated GIF" do
      it "stores exactly 2 thumbnail files and no sample files" do
        allow(post).to receive(:is_gif?).and_return(true)
        stub_thumbnail
        stub_sample

        described_class.generate_post_images(post)

        expect(sm).to have_received(:store).exactly(2).times
        expect(described_class).not_to have_received(:sample)
      end
    end

    context "when the post is an animated PNG" do
      it "stores exactly 2 thumbnail files and no sample files" do
        allow(post).to receive(:is_animated_png?).with(file_path).and_return(true)
        stub_thumbnail
        stub_sample

        described_class.generate_post_images(post)

        expect(sm).to have_received(:store).exactly(2).times
        expect(described_class).not_to have_received(:sample)
      end
    end

    context "when the post is an animated WebP" do
      it "stores exactly 2 thumbnail files and no sample files" do
        allow(post).to receive(:is_animated_webp?).with(file_path).and_return(true)
        stub_thumbnail
        stub_sample

        described_class.generate_post_images(post)

        expect(sm).to have_received(:store).exactly(2).times
        expect(described_class).not_to have_received(:sample)
      end
    end

    context "when the image is too small for a sample (256x256, large_image_width=850)" do
      # dimensions.min=256 is not > 850, dimensions.max=256 is not > 1700
      it "stores exactly 2 thumbnail files and no sample files" do
        stub_thumbnail
        stub_sample

        described_class.generate_post_images(post)

        expect(sm).to have_received(:store).exactly(2).times
        expect(described_class).not_to have_received(:sample)
      end
    end

    context "when the image is large enough to require a sample (1000x1000)" do
      let(:post) do
        instance_double(
          Post,
          file_path:         file_path,
          is_flash?:         false,
          is_video?:         false,
          is_gif?:           false,
          is_animated_png?:  false,
          is_animated_webp?: false,
          image_width:       1000,
          image_height:      1000,
          bg_color:          "000000",
        )
      end

      it "stores 2 thumbnail files and 2 sample files (4 store calls total)" do
        stub_thumbnail
        stub_sample

        described_class.generate_post_images(post)

        expect(sm).to have_received(:store).exactly(4).times
      end
    end

    context "when the post is a video (dimensions do not matter)" do
      let(:video_path) { file_fixture("animated.mp4").to_s }
      let(:post) do
        instance_double(
          Post,
          file_path:         video_path,
          is_flash?:         false,
          is_video?:         true,
          is_gif?:           false,
          is_animated_png?:  false,
          is_animated_webp?: false,
          image_width:       256,
          image_height:      256,
          bg_color:          "000000",
        )
      end

      it "stores thumbnails and samples regardless of dimensions" do
        stub_thumbnail
        stub_sample

        described_class.generate_post_images(post)

        expect(sm).to have_received(:store).exactly(4).times
      end
    end
  end

  # -------------------------------------------------------------------------
  # .generate_replacement_images
  # -------------------------------------------------------------------------
  describe ".generate_replacement_images" do
    let(:replacement_path) { file_fixture("replacement.jpg").to_s }
    let(:replacement) do
      instance_double(
        PostReplacement,
        replacement_file_path: replacement_path,
        file_ext:              "jpg",
        is_video?:             false,
        image_width:           256,
        image_height:          256,
      )
    end

    before do
      allow(sm).to receive(:store_replacement)
    end

    context "when the file does not exist" do
      it "returns without calling StorageManager" do
        allow(File).to receive(:exist?).with(replacement_path).and_return(false)
        described_class.generate_replacement_images(replacement)
        expect(sm).not_to have_received(:store_replacement)
      end
    end

    context "when the replacement is a SWF file" do
      it "returns without calling StorageManager" do
        allow(replacement).to receive(:file_ext).and_return("swf")
        described_class.generate_replacement_images(replacement)
        expect(sm).not_to have_received(:store_replacement)
      end
    end

    context "happy path" do
      it "calls store_replacement exactly once (jpg preview only)" do
        described_class.generate_replacement_images(replacement)
        expect(sm).to have_received(:store_replacement).once
      end

      it "calls store_replacement with the :preview size argument" do
        described_class.generate_replacement_images(replacement)
        expect(sm).to have_received(:store_replacement).with(anything, replacement, :preview)
      end
    end
  end
end
