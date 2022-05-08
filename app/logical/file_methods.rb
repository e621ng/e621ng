module FileMethods
  def is_image?
    file_ext =~ /jpg|jpeg|gif|png/i
  end

  def is_png?
    file_ext =~ /png/i
  end

  def is_gif?
    file_ext =~ /gif/i
  end

  def is_flash?
    file_ext =~ /swf/i
  end

  def is_webm?
    file_ext =~ /webm/i
  end

  def is_mp4?
    file_ext =~ /mp4/i
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
      image_size = ImageSpec.new(file_path)
      [image_size.width, image_size.height]

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
end
