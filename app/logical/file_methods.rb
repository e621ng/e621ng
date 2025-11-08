# frozen_string_literal: true

module FileMethods
  def is_image?
    is_png? || is_jpg? || is_gif? || is_webp?
  end

  def is_png?
    file_ext == "png"
  end

  def is_jpg?
    file_ext == "jpg"
  end

  def is_gif?
    file_ext == "gif"
  end

  def is_flash?
    file_ext == "swf"
  end

  def is_webm?
    file_ext == "webm"
  end

  def is_mp4?
    file_ext == "mp4"
  end

  def is_webp?
    file_ext == "webp"
  end

  def is_video?
    is_webm? || is_mp4?
  end

  def is_animated_png?(file_path)
    is_png? && ApngInspector.new(file_path).inspect!.animated?
  end

  def is_animated_gif?(file_path)
    return false unless is_gif?

    # Check whether the gif has multiple frames by trying to load the second frame.
    result = Vips::Image.gifload(file_path, page: 1) rescue $ERROR_INFO
    if result.is_a?(Vips::Image)
      true
    elsif result.is_a?(Vips::Error) && result.message =~ /bad page number/
      false
    else
      raise result
    end
  end

  # Returns true if the WebP file is animated, false otherwise.
  # Fast-ish approach: scans the file header for animation markers (ANIM/ANMF).
  # See: https://developers.google.com/speed/webp/docs/riff_container#extended
  def is_animated_webp?(file_path)
    return false unless is_webp?

    File.open(file_path, "rb") do |f|
      header = f.read(12)
      # Expect: 'RIFF' <size:LE32> 'WEBP'
      return false unless header && header.bytesize == 12
      return false unless header[0, 4] == "RIFF" && header[8, 4] == "WEBP"

      # Iterate over chunks: <FourCC:4><Size:LE32><Payload...> (padded to even length)
      loop do
        chunk_header = f.read(8)
        break false unless chunk_header && chunk_header.bytesize == 8

        # ANIM = animation header, ANMF = animation frame
        return true if %w[ANIM ANMF].include?(chunk_header[0, 4])

        # Skip payload (+ padding byte if size is odd)
        chunk_size = chunk_header[4, 4].unpack1("V") # Little-endian uint32
        skip = chunk_size + (chunk_size.odd? ? 1 : 0)
        f.seek(skip, IO::SEEK_CUR)
      end
    end
  rescue StandardError => _e
    false
  end

  def file_header_to_file_ext(file_path)
    File.open file_path do |bin|
      mime_type = Marcel::MimeType.for(bin)
      case mime_type
      when "image/jpeg"
        "jpg"
      when "image/gif"
        "gif"
      when "image/png"
        "png"
      when "video/webm"
        "webm"
      when "video/mp4"
        "mp4"
      when "image/webp"
        "webp"
      else
        mime_type
      end
    end
  end

  def calculate_dimensions(file_path)
    if is_video?
      video = FFMPEG::Movie.new(file_path)
      [video.width, video.height]

    elsif is_image?
      image = Vips::Image.new_from_file(file_path)
      [image.width, image.height]

    else
      [0, 0]
    end
  end

  def video(file_path)
    @video ||= FFMPEG::Movie.new(file_path)
  end

  def video_duration(file_path)
    return video(file_path).duration if is_video? && video(file_path).duration
    nil
  end

  def is_corrupt_gif?(file_path)
    Vips::Image.gifload(file_path, n: -1, fail: true).stats
    false
  rescue Vips::Error
    true
  end

  # Verify whether the file at the provided path is corrupt.
  # * Regular images: attempt to load the image with libvips.
  # * GIFs: attempt to load each frame with libvips.
  # * APNG: not implemented, could defer to ffmpeg if needed.
  # * Other file types: assumed to be non-corrupt.
  def is_corrupt?(file_path)
    return false unless is_image?
    return is_corrupt_gif?(file_path) if is_gif?

    begin
      Vips::Image.new_from_file(file_path, fail: true).stats
      false
    rescue Vips::Error
      true
    end
  end
end
