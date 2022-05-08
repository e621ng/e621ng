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
end
