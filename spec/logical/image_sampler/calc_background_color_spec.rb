# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  describe ".calc_background_color" do
    it "converts a 6-char lowercase hex string to [r, g, b]" do
      expect(described_class.calc_background_color("ff8040")).to eq([255, 128, 64])
    end

    it "strips a leading # before parsing" do
      expect(described_class.calc_background_color("#ff8040")).to eq([255, 128, 64])
    end

    it "handles uppercase hex" do
      expect(described_class.calc_background_color("FF8040")).to eq([255, 128, 64])
    end

    it "returns [0, 0, 0] for '000000'" do
      expect(described_class.calc_background_color("000000")).to eq([0, 0, 0])
    end

    it "returns [255, 255, 255] for 'ffffff'" do
      expect(described_class.calc_background_color("ffffff")).to eq([255, 255, 255])
    end

    it "uses the default '152f56' when called with no argument" do
      allow(Danbooru.config.custom_configuration).to receive(:default_bg_color).and_return("0088ff")
      expect(described_class.calc_background_color).to eq([0, 136, 255])
    end

    context "when hex_color is blank" do
      it "falls back to the default for an empty string" do
        allow(Danbooru.config.custom_configuration).to receive(:default_bg_color).and_return("0088ff")
        expect(described_class.calc_background_color("")).to eq([0, 136, 255])
      end

      it "falls back to the default for nil" do
        allow(Danbooru.config.custom_configuration).to receive(:default_bg_color).and_return("0088ff")
        expect(described_class.calc_background_color(nil)).to eq([0, 136, 255])
      end
    end
  end
end
