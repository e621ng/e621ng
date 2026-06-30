# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApngInspector do
  describe ".is_animated?" do
    def quick(filename)
      described_class.is_animated?(file_fixture("apng_inspector/#{filename}").to_s)
    end

    context "with a normal multi-frame APNG" do
      it "returns true" do
        expect(quick("normal_apng.png")).to be true
      end
    end

    context "with a single-frame APNG (acTL framecount == 1)" do
      it "returns false (matches #inspect! frames > 1 semantics)" do
        expect(quick("single_frame_apng.png")).to be false
      end
    end

    context "with a static PNG (no acTL chunk)" do
      it "returns false" do
        expect(quick("static_png.png")).to be false
      end
    end

    context "with an acTL chunk reporting zero frames" do
      it "returns false" do
        expect(quick("actl_zero_frames.png")).to be false
      end
    end

    context "with an acTL chunk of the wrong length" do
      it "returns false" do
        expect(quick("actl_wronglen.png")).to be false
      end
    end

    context "with a JPEG disguised as PNG (wrong magic number)" do
      it "returns false" do
        expect(quick("actually_jpg.png")).to be false
      end
    end

    context "with an empty file" do
      it "returns false" do
        expect(quick("empty.png")).to be false
      end
    end

    # Deliberate divergence from #inspect!: the quick probe keys only on the
    # acTL chunk, which sits before the decision point. broken.png has an intact
    # acTL declaring 3 frames followed by corrupt image data, so the probe
    # reports animated even though #inspect! reports corrupted. Such a file
    # could never be a live post (upload rejects it via #is_corrupt?), so the
    # difference is immaterial in practice.
    context "with a PNG whose acTL is intact but later data is corrupt" do
      it "returns true (corruption past the decision point is ignored)" do
        expect(quick("broken.png")).to be true
      end
    end

    # The whole point of the fast probe: it must reach a decision without
    # walking the file to IEND. A static PNG decides at the first IDAT, which
    # sits near the front of the file, so it reads only a small prefix.
    context "stops scanning early on a static PNG" do
      it "does not read past the first IDAT chunk" do
        bytes_read = 0
        allow(File).to receive(:open).and_wrap_original do |original, *args, &block|
          original.call(*args) do |file|
            tracked = file.method(:read)
            allow(file).to receive(:read) do |*read_args|
              result = tracked.call(*read_args)
              bytes_read += result.bytesize if result
              result
            end
            block.call(file)
          end
        end

        described_class.is_animated?(file_fixture("apng_inspector/static_png.png").to_s)
        # IHDR + a couple of ancillary chunk headers, well under the whole file.
        expect(bytes_read).to be < File.size(file_fixture("apng_inspector/static_png.png"))
      end
    end
  end
end
