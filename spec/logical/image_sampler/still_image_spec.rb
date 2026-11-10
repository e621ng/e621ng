# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  describe ".with_still_image" do
    %w[sample.jpg sample.png sample.webp].each do |fixture|
      it "yields the file itself for #{fixture}" do
        path = file_fixture(fixture).to_s
        expect { |block| described_class.with_still_image(path, &block) }.to yield_with_args(path)
      end
    end

    it "returns the block's value" do
      expect(described_class.with_still_image(file_fixture("sample.jpg").to_s) { :done }).to eq(:done)
    end

    context "with a video" do
      it "yields a snapshot image and deletes it afterwards" do
        snapshot_path = nil
        described_class.with_still_image(file_fixture("animated.mp4").to_s, file_ext: "mp4") do |path|
          snapshot_path = path
          expect(image_dimensions(path).first).to eq(256)
        end
        expect(File.exist?(snapshot_path)).to be(false)
      end

      it "raises a RuntimeError matching 'Could not generate video snapshot' when ffmpeg fails" do
        fake_status = instance_double(Process::Status)
        allow(fake_status).to receive(:==).with(0).and_return(false)
        allow(ExternalCommand).to receive(:run).and_return([+"stdout output", +"stderr output", fake_status])

        expect do
          described_class.with_still_image(file_fixture("animated.mp4").to_s, file_ext: "mp4") { nil }
        end.to raise_error(RuntimeError, "Could not generate video snapshot")
      end
    end
  end

  describe ".oriented_dimensions" do
    it "returns the stored dimensions for an unrotated image" do
      expect(described_class.oriented_dimensions(file_fixture("sample.jpg").to_s)).to eq([256, 256])
    end

    it "swaps them for a JPEG rotated via EXIF orientation" do
      # exif-orientation.jpg: 40x30 raster with orientation=8 (90° CCW).
      expect(described_class.oriented_dimensions(file_fixture("exif-orientation.jpg").to_s)).to eq([30, 40])
    end
  end
end
