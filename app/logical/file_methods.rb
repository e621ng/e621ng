# frozen_string_literal: true

module FileMethods
  def is_image?
    is_png? || is_jpg? || is_gif?
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

  def is_ai_generated?(file_path)
    return false if !is_image?

    image = Vips::Image.new_from_file(file_path)
    fetch = ->(key) do
      value = image.get(key)
      value.encode("ASCII", invalid: :replace, undef: :replace).gsub("\u0000", "")
    rescue Vips::Error
      ""
    end

    return true if fetch.call("png-comment-0-parameters").present?
    return true if fetch.call("png-comment-0-Dream").present?
    return true if fetch.call("exif-ifd0-Software").include?("NovelAI") || fetch.call("png-comment-2-Software").include?("NovelAI")
    return true if ["exif-ifd0-ImageDescription", "exif-ifd2-UserComment", "png-comment-4-Comment"].any? { |field| fetch.call(field).include?('"sampler": "') }
    exif_data = fetch.call("exif-data")
    return true if ["Model hash", "OpenAI", "NovelAI"].any? { |marker| exif_data.include?(marker) }
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

  def is_corrupt?(file_path)
    image = Vips::Image.new_from_file(file_path, fail: true)
    image.stats
    false
  rescue
    true
  end
end
