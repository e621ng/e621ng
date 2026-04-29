# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      small_image_width: 256,
      large_image_width: 850,
    )
  end

  # -------------------------------------------------------------------------
  # .thumbnail
  # -------------------------------------------------------------------------
  describe ".thumbnail" do
    let(:image) { Vips::Image.new_from_file(file_fixture("sample.jpg").to_s) }
    # sample.jpg is 256×256; dimensions passed explicitly to calc_dimensions
    let(:dimensions) { [256, 256] }
    let(:result) { described_class.thumbnail(image, dimensions) }

    after { result.each_value(&:close!) }

    it "returns a hash with :jpg and :webp keys" do
      expect(result.keys).to contain_exactly(:jpg, :webp)
    end

    it ":jpg value is a non-empty Tempfile" do
      expect(result[:jpg]).to be_a(Tempfile)
      expect(File.size(result[:jpg].path)).to be > 0
    end

    it ":webp value is a non-empty Tempfile" do
      expect(result[:webp]).to be_a(Tempfile)
      expect(File.size(result[:webp].path)).to be > 0
    end

    it "both Tempfiles can be close!'d without error" do
      expect { result.each_value(&:close!) }.not_to raise_error
    end

    context "with portrait dimensions that trigger cropping (calc_dimensions sees [100, 400])" do
      # scale = 256/100 = 2.56; scaled height = 400*2.56 = 1024 > 512 → smartcrop fires
      # The actual image is 256×256 but will be scaled to 655×655 before cropping.
      it "still returns valid :jpg and :webp Tempfiles" do
        result = described_class.thumbnail(image, [100, 400])
        expect(result[:jpg]).to be_a(Tempfile)
        expect(File.size(result[:jpg].path)).to be > 0
        expect(result[:webp]).to be_a(Tempfile)
        expect(File.size(result[:webp].path)).to be > 0
        result.each_value(&:close!)
      end
    end

    context "with a custom background color" do
      it "accepts a hex background string without raising" do
        expect do
          result = described_class.thumbnail(image, dimensions, background: "ff0000")
          result.each_value(&:close!)
        end.not_to raise_error
      end
    end
  end

  # -------------------------------------------------------------------------
  # .sample
  # -------------------------------------------------------------------------
  describe ".sample" do
    let(:image) { Vips::Image.new_from_file(file_fixture("sample.jpg").to_s) }
    let(:dimensions) { [256, 256] }
    let(:result) { described_class.sample(image, dimensions) }

    after { result.each_value(&:close!) }

    it "returns a hash with :jpg and :webp keys" do
      expect(result.keys).to contain_exactly(:jpg, :webp)
    end

    it ":jpg file has non-zero size" do
      expect(File.size(result[:jpg].path)).to be > 0
    end

    it ":webp file has non-zero size" do
      expect(File.size(result[:webp].path)).to be > 0
    end
  end

  # -------------------------------------------------------------------------
  # .thumbnail_from_path
  # -------------------------------------------------------------------------
  describe ".thumbnail_from_path" do
    let(:file_path) { file_fixture("sample.jpg").to_s }
    let(:dimensions) { [256, 256] }
    let(:result) { described_class.thumbnail_from_path(file_path, dimensions) }

    after { result.each_value(&:close!) }

    it "returns a hash with :jpg and :webp keys" do
      expect(result.keys).to contain_exactly(:jpg, :webp)
    end

    it "loads the image from disk and produces non-empty output files" do
      expect(File.size(result[:jpg].path)).to be > 0
      expect(File.size(result[:webp].path)).to be > 0
    end
  end

  # -------------------------------------------------------------------------
  # .sample_from_path
  # -------------------------------------------------------------------------
  describe ".sample_from_path" do
    let(:file_path) { file_fixture("sample.jpg").to_s }
    let(:dimensions) { [256, 256] }
    let(:result) { described_class.sample_from_path(file_path, dimensions) }

    after { result.each_value(&:close!) }

    it "returns a hash with :jpg and :webp keys" do
      expect(result.keys).to contain_exactly(:jpg, :webp)
    end

    it "loads the image from disk and produces non-empty output files" do
      expect(File.size(result[:jpg].path)).to be > 0
      expect(File.size(result[:webp].path)).to be > 0
    end
  end
end
