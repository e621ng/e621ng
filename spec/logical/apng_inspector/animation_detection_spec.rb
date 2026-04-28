# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApngInspector do
  describe "#inspect!" do
    context "with a normal multi-frame APNG" do
      subject { described_class.new(file_fixture("apng_inspector/normal_apng.png").to_s).inspect! }

      it "is not corrupted" do
        expect(subject.corrupted?).to be false
      end

      it "is animated" do
        expect(subject.animated?).to be true
      end

      it "has more than one frame" do
        expect(subject.frames).to be > 1
      end
    end

    context "with a single-frame APNG (acTL framecount == 1)" do
      subject { described_class.new(file_fixture("apng_inspector/single_frame_apng.png").to_s).inspect! }

      it "is not corrupted" do
        expect(subject.corrupted?).to be false
      end

      it "is not animated" do
        expect(subject.animated?).to be false
      end

      it "has exactly one frame" do
        expect(subject.frames).to eq(1)
      end
    end

    context "with a static PNG (no acTL chunk)" do
      subject { described_class.new(file_fixture("apng_inspector/static_png.png").to_s).inspect! }

      it "is not corrupted" do
        expect(subject.corrupted?).to be false
      end

      it "is not animated" do
        expect(subject.animated?).to be false
      end

      it "has no frame count" do
        expect(subject.frames).to be_nil
      end
    end
  end
end
