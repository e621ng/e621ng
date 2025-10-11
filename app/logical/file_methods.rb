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

  def is_avif?
    file_ext == "avif"
  end

  def is_jxl?
    # file_ext == "jxl"
    false # Unsupported in browsers
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
    i = 0
    loop do
      Vips::Image.gifload(file_path, page: i, fail: true).stats
      i += 1
    end
  rescue Vips::Error => e
    # Invalid page number indicates we've reached the end of the frames.
    # Any other error indicates corruption.
    return false if e.message =~ /bad page number/
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
