# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApngInspector do
  describe "#inspect!" do
    shared_examples "a corrupted file" do
      it "is corrupted" do
        expect(subject.corrupted?).to be true
      end

      it "is not animated" do
        expect(subject.animated?).to be false
      end
    end

    context "with an empty file" do
      subject { described_class.new(file_fixture("apng_inspector/empty.png").to_s).inspect! }

      include_examples "a corrupted file"

      it "has no frame count" do
        expect(subject.frames).to be_nil
      end
    end

    context "with a JPEG disguised as PNG (wrong magic number)" do
      subject { described_class.new(file_fixture("apng_inspector/actually_jpg.png").to_s).inspect! }

      include_examples "a corrupted file"

      it "has no frame count" do
        expect(subject.frames).to be_nil
      end
    end

    context "with a broken/truncated PNG" do
      subject { described_class.new(file_fixture("apng_inspector/broken.png").to_s).inspect! }

      include_examples "a corrupted file"
    end

    context "with a PNG missing the IEND chunk" do
      subject { described_class.new(file_fixture("apng_inspector/iend_missing.png").to_s).inspect! }

      include_examples "a corrupted file"
    end

    context "with a PNG with misaligned chunks" do
      subject { described_class.new(file_fixture("apng_inspector/misaligned_chunks.png").to_s).inspect! }

      include_examples "a corrupted file"
    end

    context "with an acTL chunk reporting zero frames" do
      subject { described_class.new(file_fixture("apng_inspector/actl_zero_frames.png").to_s).inspect! }

      include_examples "a corrupted file"

      it "has no frame count" do
        expect(subject.frames).to be_nil
      end
    end

    context "with an acTL chunk of wrong length" do
      subject { described_class.new(file_fixture("apng_inspector/actl_wronglen.png").to_s).inspect! }

      include_examples "a corrupted file"

      it "has no frame count" do
        expect(subject.frames).to be_nil
      end
    end
  end
end
