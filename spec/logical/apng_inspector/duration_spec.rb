# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApngInspector do
  describe ".duration" do
    def duration(filename)
      described_class.duration(file_fixture("apng_inspector/#{filename}").to_s)
    end

    def chunk(name, data)
      [data.bytesize].pack("N") + name + data + [Zlib.crc32(name + data)].pack("N")
    end

    def fctl(sequence, delay_num, delay_den)
      chunk("fcTL", [sequence, 1, 1, 0, 0, delay_num, delay_den, 0, 0].pack("NNNNNnnCC"))
    end

    def apng_with(*frames)
      Tempfile.create(["apng", ".png"]) do |file|
        file.binmode
        file.write(ApngInspector::PNG_MAGIC_NUMBER)
        file.write(chunk("IHDR", [1, 1, 8, 6, 0, 0, 0].pack("NNCCCCC")))
        file.write(chunk("acTL", [frames.size, 0].pack("NN")))
        frames.each.with_index { |(num, den), i| file.write(fctl(i, num, den)) }
        file.write(chunk("IEND", ""))
        file.flush
        return described_class.duration(file.path)
      end
    end

    it "sums the frame delays of an animated PNG" do
      expect(described_class.duration(file_fixture("animated.png").to_s)).to be_within(0.01).of(2.0)
    end

    it "returns a positive duration for a normal APNG" do
      expect(duration("normal_apng.png")).to be > 0
    end

    it "treats a zero delay denominator as hundredths of a second" do
      expect(apng_with([25, 0], [1, 4])).to be_within(0.001).of(0.5)
    end

    it "counts zero-delay frames as zero" do
      expect(apng_with([0, 100], [0, 100])).to eq(0.0)
    end

    %w[single_frame_apng.png static_png.png actl_zero_frames.png actl_wronglen.png broken.png empty.png actually_jpg.png].each do |filename|
      it "returns nil for #{filename}" do
        expect(duration(filename)).to be_nil
      end
    end

    it "returns nil for a missing file" do
      expect(described_class.duration("/nonexistent/path.png")).to be_nil
    end
  end
end
