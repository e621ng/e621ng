# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApngInspector do
  describe "#each_chunk" do
    context "with a valid PNG" do
      it "returns true" do
        inspector = described_class.new(file_fixture("apng_inspector/static_png.png").to_s)
        result = inspector.each_chunk { |_name, _len, _file| nil }
        expect(result).to be true
      end
    end

    context "with a non-PNG file (wrong magic number)" do
      it "returns false" do
        inspector = described_class.new(file_fixture("apng_inspector/actually_jpg.png").to_s)
        result = inspector.each_chunk { |_name, _len, _file| nil }
        expect(result).to be false
      end
    end

    context "with an empty file" do
      it "returns false" do
        inspector = described_class.new(file_fixture("apng_inspector/empty.png").to_s)
        result = inspector.each_chunk { |_name, _len, _file| nil }
        expect(result).to be false
      end
    end

    context "with a broken/truncated PNG" do
      it "returns false" do
        inspector = described_class.new(file_fixture("apng_inspector/broken.png").to_s)
        result = inspector.each_chunk { |_name, _len, _file| nil }
        expect(result).to be false
      end
    end
  end
end
