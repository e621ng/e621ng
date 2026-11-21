# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebpInspector do
  describe ".is_animated?" do
    it "returns true for an animated WebP" do
      expect(described_class.is_animated?(file_fixture("animated.webp").to_s)).to be true
    end

    it "returns false for a static WebP" do
      expect(described_class.is_animated?(file_fixture("sample.webp").to_s)).to be false
    end

    it "returns false for a non-WebP file" do
      expect(described_class.is_animated?(file_fixture("animated.png").to_s)).to be false
    end
  end

  describe ".duration" do
    it "sums the frame durations of an animated WebP" do
      expect(described_class.duration(file_fixture("animated.webp").to_s)).to be_within(0.001).of(2.0)
    end

    it "returns nil for a static WebP" do
      expect(described_class.duration(file_fixture("sample.webp").to_s)).to be_nil
    end

    it "returns nil for a non-WebP file" do
      expect(described_class.duration(file_fixture("animated.gif").to_s)).to be_nil
    end

    it "returns nil for a missing file" do
      expect(described_class.duration("/nonexistent/path.webp")).to be_nil
    end
  end

  describe "scan budget (E6SEC-411)" do
    # A bare chunk: 4-char FourCC + LE32 size + `size` payload bytes, padded to even length.
    def chunk(name, size = 0)
      "#{name}#{[size].pack('V')}#{"\0" * (size + (size.odd? ? 1 : 0))}"
    end

    # An ANMF chunk whose 16-byte payload carries a 3-byte little-endian duration (ms) at offset 12.
    def frame(duration_ms)
      payload = "#{"\0" * 12}#{[duration_ms].pack('V')[0, 3]}\0"
      "ANMF#{[payload.bytesize].pack('V')}#{payload}"
    end

    # Writes a WebP with the given chunk body to a tempfile and yields its path.
    def with_webp(body)
      Tempfile.create(["webp", ".webp"]) do |t|
        t.binmode
        t.write("RIFF#{[0].pack('V')}WEBP#{body}")
        t.flush
        yield t.path
      end
    end

    it "stops walking after CHUNK_LIMIT chunks and does not see what lies beyond" do
      stub_const("WebpInspector::CHUNK_LIMIT", 5)
      # 6 junk chunks exhaust the budget before the ANMF, which must therefore go unseen.
      with_webp("#{chunk('JUNK') * 6}#{chunk('ANMF', 16)}") do |path|
        expect(described_class.is_animated?(path)).to be false
      end
    end

    it "returns nil rather than a partial total when a real frame lies beyond the budget" do
      stub_const("WebpInspector::CHUNK_LIMIT", 2)
      # One in-budget 1s frame, then junk to exhaust the budget, then a 5s frame past it.
      with_webp("#{frame(1000)}#{chunk('JUNK')}#{chunk('JUNK')}#{frame(5000)}") do |path|
        expect(described_class.duration(path)).to be_nil
      end
    end

    it "stops once BYTES_LIMIT is exceeded without seeking past an oversized declared size" do
      stub_const("WebpInspector::BYTES_LIMIT", 100)
      # A chunk claiming a 1 GB payload (none written): rejected on the budget, never sought.
      with_webp("JUNK#{[1_000_000_000].pack('V')}#{frame(5000)}") do |path|
        expect(described_class.is_animated?(path)).to be false
        expect(described_class.duration(path)).to be_nil
      end
    end

    it "still detects animation and sums durations within the budget, honouring odd padding" do
      stub_const("WebpInspector::CHUNK_LIMIT", 10)
      # An odd-sized chunk (padded to even) must not desync the following frames.
      with_webp("#{chunk('VP8X', 3)}#{chunk('ANIM', 6)}#{frame(1500)}#{frame(500)}") do |path|
        expect(described_class.is_animated?(path)).to be true
        expect(described_class.duration(path)).to be_within(0.001).of(2.0)
      end
    end
  end
end
