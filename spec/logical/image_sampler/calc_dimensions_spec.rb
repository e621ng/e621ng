# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  # -------------------------------------------------------------------------
  # .calc_dimensions — dispatch
  # -------------------------------------------------------------------------
  describe ".calc_dimensions" do
    it "delegates to calc_dimensions_for_preview when crop: true" do
      allow(described_class).to receive(:calc_dimensions_for_preview).and_call_original
      described_class.calc_dimensions(100, 200, 256, crop: true)
      expect(described_class).to have_received(:calc_dimensions_for_preview).with(100, 200, 256)
    end

    it "delegates to calc_dimensions_for_sample when crop: false" do
      allow(described_class).to receive(:calc_dimensions_for_sample).and_call_original
      described_class.calc_dimensions(100, 200, 256, crop: false)
      expect(described_class).to have_received(:calc_dimensions_for_sample).with(100, 200, 256)
    end
  end

  # -------------------------------------------------------------------------
  # .calc_dimensions_for_preview
  # -------------------------------------------------------------------------
  describe ".calc_dimensions_for_preview" do
    # limit = 256 used throughout unless otherwise noted

    context "with a portrait image that does NOT exceed 2x limit after scaling" do
      # 100×150, limit=256 → scale=2.56, scaled height=384 < 512 → no crop
      it "returns [scale, nil]" do
        scale, crop_area = described_class.calc_dimensions_for_preview(100, 150, 256)
        expect(scale).to be_within(1e-9).of(256.0 / 100)
        expect(crop_area).to be_nil
      end
    end

    context "with a portrait image that EXCEEDS 2x limit after scaling" do
      # 100×400, limit=256 → scale=2.56, scaled height=1024 > 512 → crop=[256, 512]
      it "returns [scale, [limit, limit*2]]" do
        scale, crop_area = described_class.calc_dimensions_for_preview(100, 400, 256)
        expect(scale).to be_within(1e-9).of(256.0 / 100)
        expect(crop_area).to eq([256, 512])
      end
    end

    context "with a landscape image that does NOT exceed 2x limit after scaling" do
      # 150×100, limit=256 → scale=2.56, scaled width=384 < 512 → no crop
      it "returns [scale, nil]" do
        scale, crop_area = described_class.calc_dimensions_for_preview(150, 100, 256)
        expect(scale).to be_within(1e-9).of(256.0 / 100)
        expect(crop_area).to be_nil
      end
    end

    context "with a landscape image that EXCEEDS 2x limit after scaling" do
      # 400×100, limit=256 → scale=2.56, scaled width=1024 > 512 → crop=[512, 256]
      it "returns [scale, [limit*2, limit]]" do
        scale, crop_area = described_class.calc_dimensions_for_preview(400, 100, 256)
        expect(scale).to be_within(1e-9).of(256.0 / 100)
        expect(crop_area).to eq([512, 256])
      end
    end

    context "with a square image" do
      it "returns [limit/width, nil]" do
        scale, crop_area = described_class.calc_dimensions_for_preview(200, 200, 256)
        expect(scale).to be_within(1e-9).of(256.0 / 200)
        expect(crop_area).to be_nil
      end
    end

    context "when called without an explicit limit" do
      it "uses Danbooru.config.small_image_width as the limit" do
        allow(Danbooru.config.custom_configuration).to receive(:small_image_width).and_return(256)
        scale, = described_class.calc_dimensions_for_preview(200, 200)
        expect(scale).to be_within(1e-9).of(256.0 / 200)
      end
    end
  end

  # -------------------------------------------------------------------------
  # .calc_dimensions_for_sample
  # -------------------------------------------------------------------------
  describe ".calc_dimensions_for_sample" do
    it "always returns nil as the second element (never crops)" do
      _, crop_area = described_class.calc_dimensions_for_sample(100, 200, 850)
      expect(crop_area).to be_nil
    end

    context "with a portrait image that fits within 2x limit" do
      # 100×150, limit=850 → scale=8.5, scaled height=1275 < 1700 → keep scale
      it "returns limit/width as scale" do
        scale, = described_class.calc_dimensions_for_sample(100, 150, 850)
        expect(scale).to be_within(1e-9).of(850.0 / 100)
      end
    end

    context "with a portrait image whose height exceeds 2x limit after width-based scale" do
      # 100×900, limit=850 → first scale=8.5, scaled height=7650 > 1700 → clamp to 1700/900
      it "returns (limit*2)/height as scale" do
        scale, = described_class.calc_dimensions_for_sample(100, 900, 850)
        expect(scale).to be_within(1e-9).of(1700.0 / 900)
      end
    end

    context "with a landscape image that fits within 2x limit" do
      # 150×100, limit=850 → scale=8.5, scaled width=1275 < 1700 → keep scale
      it "returns limit/height as scale" do
        scale, = described_class.calc_dimensions_for_sample(150, 100, 850)
        expect(scale).to be_within(1e-9).of(850.0 / 100)
      end
    end

    context "with a landscape image whose width exceeds 2x limit after height-based scale" do
      # 900×100, limit=850 → first scale=8.5, scaled width=7650 > 1700 → clamp to 1700/900
      it "returns (limit*2)/width as scale" do
        scale, = described_class.calc_dimensions_for_sample(900, 100, 850)
        expect(scale).to be_within(1e-9).of(1700.0 / 900)
      end
    end

    context "with a square image" do
      it "returns limit/width as scale" do
        scale, = described_class.calc_dimensions_for_sample(200, 200, 850)
        expect(scale).to be_within(1e-9).of(850.0 / 200)
      end
    end

    context "when called without an explicit limit" do
      it "uses Danbooru.config.large_image_width as the limit" do
        allow(Danbooru.config.custom_configuration).to receive(:large_image_width).and_return(850)
        scale, = described_class.calc_dimensions_for_sample(200, 200)
        expect(scale).to be_within(1e-9).of(850.0 / 200)
      end
    end
  end
end
