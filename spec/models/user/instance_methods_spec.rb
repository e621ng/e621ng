# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  describe "flair color handling" do
    let(:user) { create(:user) }

    it "accepts hex strings and returns hex and rgb values" do
      user.flair_color_hex = "#ff8800"
      expect(user.flair_color).to eq(0xff8800)
      expect(user.flair_color_hex).to eq("#ff8800")
      expect(user.flair_color_rgb).to eq([0xff, 0x88, 0x00])

      user.flair_color_hex = "00ff00"
      expect(user.flair_color).to eq(0x00ff00)
      expect(user.flair_color_hex).to eq("#00ff00")
      expect(user.flair_color_rgb).to eq([0x00, 0xff, 0x00])
    end

    it "handles nil and blank values" do
      user.flair_color_hex = ""
      expect(user.flair_color).to be_nil
      expect(user.flair_color_hex).to be_nil

      user.flair_color_hex = nil
      expect(user.flair_color).to be_nil
      expect(user.flair_color_hex).to be_nil
    end

    it "does not accept invalid hex strings" do
      ["gghhii", "#12345", "#xyz", "1234567"].each do |invalid_hex|
        user.flair_color_hex = invalid_hex
        expect(user.flair_color_hex).not_to eq(invalid_hex)
      end
    end

    it "ignores wildcard assignment in the setter" do
      user.flair_color_hex = "abc*"
      expect(user.flair_color).to be_nil
    end

    it "falls back to a deterministic color when no value is set" do
      user.flair_color_hex = nil

      fallback_color = user.user_color
      expect(fallback_color).to match(/\A#?[0-9a-fA-F]{6}\z/i)
      expect(user.user_color).to eq(fallback_color)
    end
  end
end
