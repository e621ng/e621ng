# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImageSampler do
  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      small_image_width: 256,
      large_image_width: 850,
    )
  end

  let(:tempfiles) { [] }

  after { tempfiles.each(&:close!) }

  # Writes a plain grey image of the given size and returns its path.
  def image_file(width, height)
    file = Tempfile.new(["image-sampler", ".png"])
    tempfiles << file
    write_solid_image(file.path, width, height)
  end

  def dimensions_of(result)
    image_dimensions(result[:jpg].path)
  end

  # -------------------------------------------------------------------------
  # .thumbnail
  # -------------------------------------------------------------------------
  describe ".thumbnail" do
    let(:file_path) { file_fixture("sample.jpg").to_s }
    # sample.jpg is 256×256
    let(:result) { described_class.thumbnail(file_path, [256, 256]) }

    after { result.each_value(&:close!) }

    it "returns non-empty :jpg and :webp Tempfiles" do
      expect(result.keys).to contain_exactly(:jpg, :webp)
      expect(result.values).to all(be_a(Tempfile))
      expect(result.values.map { |file| File.size(file.path) }).to all(be > 0)
    end

    it "keeps a square image at the thumbnail size" do
      expect(dimensions_of(result)).to eq([256, 256])
    end

    it "accepts a custom background color" do
      result = described_class.thumbnail(file_path, [256, 256], background: "ff0000")
      expect(File.size(result[:jpg].path)).to be > 0
      result.each_value(&:close!)
    end

    context "with a landscape image" do
      let(:result) { described_class.thumbnail(image_file(400, 300), [400, 300]) }

      it "fits the short side to the thumbnail size" do
        expect(dimensions_of(result)).to eq([341, 256])
      end
    end

    context "with a portrait image more than twice as tall as wide" do
      let(:result) { described_class.thumbnail(image_file(100, 400), [100, 400]) }

      it "crops the long side to twice the thumbnail size" do
        expect(dimensions_of(result)).to eq([256, 512])
      end
    end

    context "with a JPEG rotated via EXIF orientation" do
      # exif-orientation.jpg: 40x30 raster with orientation=8 (90° CCW).
      let(:file_path) { file_fixture("exif-orientation.jpg").to_s }
      let(:result) { described_class.thumbnail(file_path, described_class.oriented_dimensions(file_path)) }

      it "comes out rotated" do
        expect(dimensions_of(result)).to eq([256, 341])
      end
    end

    context "with an embedded colour profile" do
      # Pure sRGB red stored with a Display P3 profile: the raw values are not 255/0/0,
      # so getting red back means the profile was applied.
      let(:file_path) do
        file = Tempfile.new(["image-sampler", ".jpg"])
        tempfiles << file
        write_p3_image(file.path, 300, 300, color: [255, 0, 0])
      end

      it "converts the result to sRGB" do
        expect(pixel_at(file_path, 150, 150).first).to be < 245
        red, green, = pixel_at(result[:jpg].path, 128, 128)
        expect(red).to be > 245
        expect(green).to be < 15
      end
    end
  end

  # -------------------------------------------------------------------------
  # .sample
  # -------------------------------------------------------------------------
  describe ".sample" do
    let(:result) { described_class.sample(image_file(2000, 1000), [2000, 1000]) }

    after { result.each_value(&:close!) }

    it "returns non-empty :jpg and :webp Tempfiles" do
      expect(result.keys).to contain_exactly(:jpg, :webp)
      expect(result.values.map { |file| File.size(file.path) }).to all(be > 0)
    end

    it "fits the short side to the sample size, capping the long side at twice that" do
      expect(dimensions_of(result)).to eq([1700, 850])
    end
  end
end
