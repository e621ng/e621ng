# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  describe ".image_from_path" do
    context "with a static JPEG" do
      it "returns a Vips::Image" do
        image = described_class.image_from_path(file_fixture("sample.jpg").to_s)
        expect(image).to be_a(Vips::Image)
      end
    end

    context "with a static PNG" do
      it "returns a Vips::Image" do
        image = described_class.image_from_path(file_fixture("sample.png").to_s)
        expect(image).to be_a(Vips::Image)
      end
    end

    context "with a static WebP" do
      it "returns a Vips::Image" do
        image = described_class.image_from_path(file_fixture("sample.webp").to_s)
        expect(image).to be_a(Vips::Image)
      end
    end

    context "with a JPEG rotated via EXIF orientation" do
      # exif-orientation.jpg: 40x30 raster with orientation=8 (90° CCW).
      let(:image) { described_class.image_from_path(file_fixture("exif-orientation.jpg").to_s) }

      it "applies the rotation" do
        expect([image.width, image.height]).to eq([30, 40])
      end

      it "removes the orientation tag" do
        expect(image.get_typeof("orientation")).to eq(0)
      end
    end

    context "with is_video: true" do
      context "when ffmpeg succeeds" do
        it "returns a Vips::Image loaded from the video snapshot" do
          image = described_class.image_from_path(file_fixture("animated.mp4").to_s, is_video: true)
          expect(image).to be_a(Vips::Image)
        end
      end

      context "when ffmpeg exits non-zero" do
        it "raises a RuntimeError matching 'Could not generate video snapshot'" do
          fake_status = instance_double(Process::Status)
          allow(fake_status).to receive(:==).with(0).and_return(false)
          allow(Open3).to receive(:capture3).and_return([+"stdout output", +"stderr output", fake_status])

          expect do
            described_class.image_from_path(file_fixture("animated.mp4").to_s, is_video: true)
          end.to raise_error(RuntimeError, "Could not generate video snapshot")
        end
      end
    end
  end
end
