# frozen_string_literal: true

# Reads animation data from the WebP RIFF container without decoding the image.
# See: https://developers.google.com/speed/webp/docs/riff_container#extended
class WebpInspector
  # Scan budget for the chunk walk. A crafted file packed with tiny (e.g. zero-size) chunks
  # must not make the walk — which runs synchronously in the request worker during upload —
  # run for a time proportional to the whole 100 MB-max file. Mirrors ApngInspector's guard.
  CHUNK_LIMIT = 100_000
  BYTES_LIMIT = 20 * 1024 * 1024

  # Raised when the scan budget is hit before the walk finishes. The public methods rescue it:
  # a truncated scan means "not fully determined", so is_animated? is false and duration is nil
  # (never a partial total that would mistag the post), matching ApngInspector.
  class ScanBudgetExceeded < StandardError; end

  # Returns true if the WebP file is animated (has an ANIM or ANMF chunk), false otherwise.
  def self.is_animated?(file_path)
    each_chunk(file_path) do |name, _size, _file|
      return true if %w[ANIM ANMF].include?(name)
    end
    false
  rescue StandardError
    false
  end

  # Total playback time in seconds of one loop, summed from the ANMF frame durations,
  # or nil if the file has no animation frames.
  def self.duration(file_path)
    frames = 0
    total_ms = 0
    each_chunk(file_path) do |name, size, file|
      next unless name == "ANMF" && size >= 16

      # Frame header: X, Y, width-1, height-1 (3 bytes each), then the 3-byte duration in ms.
      data = file.read(16)
      return nil unless data&.bytesize == 16
      total_ms += "#{data[12, 3]}\0".unpack1("V")
      frames += 1
      file.seek(-16, IO::SEEK_CUR)
    end
    frames > 0 ? total_ms / 1000.0 : nil
  rescue StandardError
    nil
  end

  # Yields each top-level chunk's FourCC and size with the file positioned at its payload.
  # The block may read from the file as long as it returns to the payload start.
  def self.each_chunk(file_path)
    File.open(file_path, "rb") do |f|
      header = f.read(12)
      # Expect: 'RIFF' <size:LE32> 'WEBP'
      next unless header && header.bytesize == 12 && header[0, 4] == "RIFF" && header[8, 4] == "WEBP"

      # Chunks: <FourCC:4><Size:LE32><Payload...> (padded to even length)
      chunks = 0
      bytes_scanned = 12 # RIFF/WEBP header
      loop do
        chunk_header = f.read(8)
        break unless chunk_header && chunk_header.bytesize == 8

        size = chunk_header[4, 4].unpack1("V")
        # Enforce the budget before yielding/seeking, so an oversized declared size
        # can't drive a seek past the limit either.
        chunks += 1
        bytes_scanned += 8 + size + (size.odd? ? 1 : 0)
        raise ScanBudgetExceeded if chunks > CHUNK_LIMIT || bytes_scanned > BYTES_LIMIT

        yield chunk_header[0, 4], size, f
        f.seek(size + (size.odd? ? 1 : 0), IO::SEEK_CUR)
      end
    end
  end

  private_class_method :each_chunk
end
