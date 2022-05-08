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
end
