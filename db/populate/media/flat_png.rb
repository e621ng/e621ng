# frozen_string_literal: true

require "zlib"

module Populate
  module Media
    # Writes a single-colour 8-bit RGB PNG. Rows are identical, so even a huge image compresses
    # to a few kilobytes and can be produced without an image library.
    module FlatPng
      SIGNATURE = "\x89PNG\r\n\x1a\n".b
      STEP_BYTES = 1 << 20

      module_function

      # A colour from the first three bytes of the md5, kept away from black and white.
      def colour_for(md5)
        md5[0, 6].scan(/../).map { |hex| hex.to_i(16).clamp(48, 208) }
      end

      def write(io, width:, height:, rgb:)
        io.write(SIGNATURE)
        chunk(io, "IHDR", [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC"))

        row = "\x00".b + (rgb.pack("C3") * width)
        rows_per_step = [STEP_BYTES / row.bytesize, 1].max
        deflate = Zlib::Deflate.new(Zlib::BEST_SPEED)
        compressed = +""
        remaining = height
        while remaining > 0
          n = [rows_per_step, remaining].min
          compressed << deflate.deflate(row * n)
          remaining -= n
        end
        compressed << deflate.finish
        deflate.close

        chunk(io, "IDAT", compressed)
        chunk(io, "IEND", "")
        io.flush
      end

      def chunk(io, type, data)
        body = type.b + data.b
        io.write([data.bytesize].pack("N"), body, [Zlib.crc32(body)].pack("N"))
      end
    end
  end
end
