# frozen_string_literal: true

class ApngInspector
  PNG_MAGIC_NUMBER = ["89504E470D0A1A0A"].pack("H*")

  # Fast APNG animation probe.
  #
  # Returns true if the file is an animated APNG (has an acTL chunk declaring more than one frame),
  # false otherwise.
  #
  # Stops scanning as soon as it sees acTL (animated) or the first IDAT/IEND (not animated) — per
  # the APNG spec, acTL must appear before any IDAT. This avoids walking the (potentially large)
  # IDAT chunk sequence all the way to IEND, which is the dominant cost on big PNGs.
  #
  # PNG structure: an 8-byte magic number followed by chunks of the form
  # <4-byte length><4-byte name><length-byte data><4-byte CRC>. The APNG frame count lives in the
  # first 4 bytes of the acTL chunk's data.
  #
  # Does NOT validate the rest of the file. Corruption past the decision point is irrelevant to
  # this question, and is checked separately on upload via FileMethods#is_corrupt?.
  def self.is_animated?(file_path, chunk_limit: 100_000, bytes_limit: 20 * 1024 * 1024)
    File.open(file_path, "rb") do |file|
      return false unless file.read(8) == PNG_MAGIC_NUMBER

      header = +""
      chunks = 0
      bytes_scanned = 8 # initial signature

      while file.read(8, header)
        return false if header.bytesize < 8

        len = header.unpack1("N")
        name = header[4, 4]

        return false if name =~ /[^A-Za-z]/ # chunk names are 4 ASCII letters

        if name == "acTL"
          # acTL is exactly 8 bytes; the first 4 hold the frame count.
          return false unless len == 8
          framedata = file.read(4)
          return false if framedata.nil? || framedata.bytesize != 4
          return framedata.unpack1("N") > 1
        elsif %w[IDAT IEND].include?(name)
          # acTL must precede IDAT, so reaching image data first means static.
          return false
        end

        # Enforce the scan limits before jumping, so an oversized declared length
        # can't trigger a seek past the budget.
        chunks += 1
        bytes_scanned += 8 + len + 4
        return false if chunks > chunk_limit || bytes_scanned > bytes_limit

        # Skip over the chunk data and its 4-byte CRC.
        file.seek(len + 4, IO::SEEK_CUR)
      end
    end

    false
  end

  # Total playback time in seconds of one loop, summed from the fcTL frame delays,
  # or nil if the file isn't a multi-frame APNG or is cut off before IEND.
  # Seeks past image data without reading it.
  def self.duration(file_path, chunk_limit: 100_000)
    File.open(file_path, "rb") do |file| # rubocop:disable Metrics/BlockLength
      return nil unless file.read(8) == PNG_MAGIC_NUMBER

      header = +""
      animated = false
      ended = false
      frames = 0
      total = 0r

      chunk_limit.times do
        break unless file.read(8, header) && header.bytesize == 8

        len = header.unpack1("N")
        name = header[4, 4]
        return nil if name =~ /[^A-Za-z]/

        case name
        when "acTL"
          return nil unless len == 8
          data = file.read(8)
          return nil unless data&.bytesize == 8
          animated = data.unpack1("N") > 1
          file.seek(4, IO::SEEK_CUR)
        when "fcTL"
          return nil unless len == 26
          data = file.read(26)
          return nil unless data&.bytesize == 26
          delay_num, delay_den = data[20, 4].unpack("nn")
          # A zero denominator means hundredths of a second.
          total += Rational(delay_num, delay_den == 0 ? 100 : delay_den)
          frames += 1
          file.seek(4, IO::SEEK_CUR)
        when "IEND"
          ended = true
          break
        else
          file.seek(len + 4, IO::SEEK_CUR)
        end
      end

      ended && animated && frames > 0 ? total.to_f : nil
    end
  rescue SystemCallError, IOError
    nil
  end
end
