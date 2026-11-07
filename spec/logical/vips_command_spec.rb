# frozen_string_literal: true

require "rails_helper"

RSpec.describe VipsCommand do
  let(:tempfiles) { [] }

  after { tempfiles.each(&:close!) }

  def tempfile(name, contents)
    file = Tempfile.new(name, binmode: true)
    tempfiles << file
    file.write(contents)
    file.flush
    file.path
  end

  describe ".dimensions" do
    it "reads the size from the header" do
      expect(described_class.dimensions(file_fixture("sample.jpg").to_s)).to eq([256, 256])
    end

    it "applies the EXIF orientation" do
      # 40x30 raster with orientation=8 (90° CCW).
      expect(described_class.dimensions(file_fixture("exif-orientation.jpg").to_s)).to eq([30, 40])
    end

    it "reads every accepted format" do
      %w[sample.jpg sample.png static.gif sample.webp].each do |name|
        expect(described_class.dimensions(file_fixture(name).to_s)).to eq([256, 256])
      end
    end
  end

  describe ".check_format!" do
    it "refuses formats outside the allow-list before libvips sees them" do
      path = tempfile(["image", ".ppm"], "P3\n1 1\n255\n0 0 0\n")
      allow(ExternalCommand).to receive(:run)
      expect { described_class.header_fields(path) }.to raise_error(described_class::UnsupportedFormat, /not a supported image format/)
      expect(ExternalCommand).not_to have_received(:run)
    end

    it "refuses a file that only claims an accepted extension" do
      path = tempfile(["image", ".jpg"], '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')
      expect { described_class.thumbnail(path, 10, height: 10) }.to raise_error(described_class::UnsupportedFormat)
    end
  end

  describe "the libvips process" do
    it "has libvips' untrusted loaders disabled even without the format check" do
      path = tempfile(["image", ".ppm"], "P3\n1 1\n255\n0 0 0\n")
      _stdout, stderr, status = ExternalCommand.run(Danbooru.config.vipsheader_path, path, env: described_class::UNTRUSTED_ENVIRONMENT, timeout: 10)
      expect(status).not_to be_success
      expect(stderr).to include("not a known file format")
    end

    it "runs single-threaded with the limited environment" do
      stdout, _stderr, _status = ExternalCommand.run("env", env: described_class::UNTRUSTED_ENVIRONMENT, timeout: 5)
      variables = stdout.lines.to_h { |line| line.chomp.split("=", 2) }
      expect(variables).to include("VIPS_CONCURRENCY" => "1", "VIPS_BLOCK_UNTRUSTED" => "1")
      expect(variables.keys - ExternalCommand::ENVIRONMENT - described_class::UNTRUSTED_ENVIRONMENT.keys).to be_empty
    end

    it "reports a timeout as an Error" do
      allow(ExternalCommand).to receive(:run).and_raise(ExternalCommand::TimeoutError, "vips timed out after 60 seconds")
      expect { described_class.corrupt?(file_fixture("sample.jpg").to_s) }.not_to raise_error
      expect { described_class.thumbnail(file_fixture("sample.jpg").to_s, 10, height: 10) }.to raise_error(described_class::Error, /timed out/)
    end
  end

  describe ".animated_gif?" do
    it "is true for a multi-frame GIF" do
      expect(described_class.animated_gif?(file_fixture("animated.gif").to_s)).to be(true)
    end

    it "is false for a single-frame GIF" do
      expect(described_class.animated_gif?(file_fixture("static.gif").to_s)).to be(false)
    end
  end

  describe ".corrupt?" do
    it "is false for an intact image" do
      expect(described_class.corrupt?(file_fixture("sample.png").to_s)).to be(false)
      expect(described_class.corrupt?(file_fixture("animated.gif").to_s, all_frames: true)).to be(false)
    end

    it "is true for a corrupt image" do
      expect(described_class.corrupt?(file_fixture("file_validator/corrupt.jpg").to_s)).to be(true)
    end

    it "is true for a truncated image" do
      path = tempfile(["image", ".jpg"], File.binread(file_fixture("sample.jpg"))[0, 300])
      expect(described_class.corrupt?(path)).to be(true)
    end
  end

  describe ".header_fields" do
    it "lists the field names, including names with spaces" do
      fields = described_class.header_fields(file_fixture("ai/generator.png").to_s)
      expect(fields.grep(/^png-comment-/).size).to eq(6)
      expect(fields).to include("width", "png-comment-4-Generation time")
    end
  end

  context "with a comment that mimics header fields" do
    let(:path) do
      file = Tempfile.new(["crafted", ".png"], binmode: true)
      tempfiles << file
      write_png_with_comment(file.path, file_fixture("sample.png"), "Comment", "hello\nwidth: 7\nheight: 9\nn-pages: 3\norientation: 6")
    end

    it "does not take the dimensions from the comment" do
      expect(described_class.dimensions(path)).to eq([256, 256])
    end

    it "does not take the frame count from the comment" do
      expect(described_class.animated_gif?(path)).to be(false)
    end

    it "yields nothing for a field name that only appears in the comment" do
      # Name discovery can be fooled, so values must always come from a -f read.
      expect(described_class.header_field(path, "n-pages")).to be_nil
    end
  end

  describe ".header_field" do
    it "returns the full value of a multi-line field" do
      value = described_class.header_field(file_fixture("ai/tokens.png").to_s, "png-comment-0-parameters")
      expect(value).to start_with("anime fox hi-res\nSteps: 20")
    end

    it "returns the raw bytes of a binary field" do
      expect(described_class.header_field(file_fixture("exif-orientation.jpg").to_s, "exif-data", binary: true)).to start_with("Exif\0\0".b)
    end

    it "is nil for a missing field" do
      expect(described_class.header_field(file_fixture("sample.png").to_s, "exif-data")).to be_nil
    end
  end

  describe ".thumbnail and .read_v" do
    it "produces a vips image of the requested size" do
      thumbnail = described_class.thumbnail(file_fixture("sample.png").to_s, 32, height: 16, size: :force)
      tempfiles << thumbnail
      image = described_class.read_v(thumbnail.path)
      expect(image).to include(width: 32, height: 16, bands: 4)
      expect(image[:pixels].bytesize).to eq(32 * 16 * 4)
    end

    it "fits within the box without forcing" do
      thumbnail = described_class.thumbnail(file_fixture("sample.png").to_s, 32, height: 16)
      tempfiles << thumbnail
      expect(described_class.read_v(thumbnail.path)).to include(width: 16, height: 16)
    end
  end

  describe ".save" do
    it "writes the image with the given options" do
      thumbnail = described_class.thumbnail(file_fixture("sample.png").to_s, 32, height: 32)
      jpg = Tempfile.new(["out", ".jpg"], binmode: true)
      tempfiles.push(thumbnail, jpg)
      described_class.save("jpegsave", thumbnail.path, jpg.path, Q: 90, strip: true, background: [255, 0, 0])
      expect(described_class.dimensions(jpg.path)).to eq([32, 32])
    end
  end
end
