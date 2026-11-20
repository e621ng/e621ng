# frozen_string_literal: true

module FileMethods
  # Types that exist on posts, including legacy swf. Accepted upload types are Danbooru.config.max_file_sizes.
  FILE_TYPE = {
    png: "png",
    jpg: "jpg",
    gif: "gif",
    swf: "swf",
    webm: "webm",
    mp4: "mp4",
    webp: "webp",
  }.freeze

  FILE_TYPE_ALIASES = {
    "flash" => "swf",
  }.freeze

  VIDEO_FILE_TYPES = %w[webm mp4].freeze

  FFPROBE_TIMEOUT = 10
  VOLUMEDETECT_TIMEOUT = 45

  # Demuxer forced for each type ffmpeg reads, so it can't pick a different one than was validated.
  FFMPEG_DEMUXERS = {
    "webm" => "matroska",
    "mp4" => "mov",
    "gif" => "gif",
  }.freeze

  # Input arguments for ffmpeg and ffprobe: the forced demuxer, and local files only.
  def self.ffmpeg_input(file_path, file_ext)
    demuxer = FFMPEG_DEMUXERS.fetch(file_ext) { raise ArgumentError, "ffmpeg can't read #{file_ext.inspect} files" }
    ["-protocol_whitelist", "file", "-f", demuxer, "-i", file_path]
  end

  def is_of_type?(type)
    file_ext == FileMethods::FILE_TYPE[type]
  end

  def is_image?
    is_png? || is_jpg? || is_gif? || is_webp?
  end

  def is_png?
    is_of_type?(:png)
  end

  def is_jpg?
    is_of_type?(:jpg)
  end

  def is_gif?
    is_of_type?(:gif)
  end

  def is_flash?
    is_of_type?(:swf)
  end

  def is_webm?
    is_of_type?(:webm)
  end

  def is_mp4?
    is_of_type?(:mp4)
  end

  def is_webp?
    is_of_type?(:webp)
  end

  def is_video?
    VIDEO_FILE_TYPES.include?(file_ext)
  end

  # Returns whether the file at the given path is animated, dispatching to the
  # type-specific probe based on file_ext. Videos are always animated.
  def is_animated_file?(file_path)
    return true if is_video?
    return is_animated_gif?(file_path) if is_gif?
    return is_animated_png?(file_path) if is_png?
    return is_animated_webp?(file_path) if is_webp?
    false
  end

  def is_animated_png?(file_path)
    is_png? && ApngInspector.is_animated?(file_path)
  end

  def is_animated_gif?(file_path)
    return false unless is_gif?

    VipsCommand.animated_gif?(file_path)
  end

  def is_animated_webp?(file_path)
    is_webp? && WebpInspector.is_animated?(file_path)
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
      stdout, stderr, status = ExternalCommand.run(Danbooru.config.ffprobe_path, "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", *FileMethods.ffmpeg_input(file_path, file_ext), timeout: FFPROBE_TIMEOUT)
      unless status.success?
        Rails.logger.warn("[FFPROBE STDERR] #{stderr.chomp}")
        raise Upload::Error, "Could not retrieve video dimensions"
      end
      stdout.chomp.split("x").map(&:to_i)
    elsif is_image?
      VipsCommand.dimensions(file_path)
    else
      [0, 0]
    end
  end

  def video(file_path)
    @video ||= VideoProbe.new(file_path, file_ext)
  end

  # Playback time in seconds for videos and animated images, nil for anything static.
  # Pass a precomputed +animated+ (e.g. from #is_animated_file?) to skip the animation probe.
  def video_duration(file_path, animated: nil)
    return video(file_path).duration if is_video?
    animated = is_animated_file?(file_path) if animated.nil?
    return nil unless animated
    return video(file_path).duration if is_gif?
    return ApngInspector.duration(file_path) if is_png?
    WebpInspector.duration(file_path) if is_webp?
  end

  def is_corrupt_gif?(file_path)
    VipsCommand.corrupt?(file_path, all_frames: true)
  end

  # A declared audio stream is not enough: many encoders mux a fully silent
  # track, so decode the audio and check its peak level against the threshold.
  def video_has_sound?(file_path)
    return false unless is_video?
    movie = video(file_path)
    raise ArgumentError, "unreadable video: #{file_path}" unless movie.valid?
    return false unless movie.has_audio?

    max_volume = video_max_volume_db(file_path)
    max_volume.present? && max_volume > Danbooru.config.sound_detection_threshold_db
  end

  # Peak level in dBFS across every audio stream, or nil when no samples were decoded.
  # Without -map ffmpeg only measures the default stream, which could be a silent one.
  def video_max_volume_db(file_path)
    stdout, stderr, status = ExternalCommand.run(Danbooru.config.ffmpeg_path, "-nostats", "-hide_banner", "-vn", "-threads", "1", "-filter_threads", "1", *FileMethods.ffmpeg_input(file_path, file_ext), "-map", "0:a", "-af", "volumedetect", "-f", "null", "-", timeout: VOLUMEDETECT_TIMEOUT)
    # ffmpeg echoes container metadata, which is not always valid UTF-8.
    stdout = stdout.scrub
    stderr = stderr.scrub
    unless status.success?
      Rails.logger.warn("[FFMPEG VOLUMEDETECT STDOUT] #{stdout.chomp}")
      Rails.logger.warn("[FFMPEG VOLUMEDETECT STDERR] #{stderr.chomp}")
      raise ArgumentError, "unreadable video: #{file_path}"
    end

    stderr.scan(/max_volume: (-?\d+(?:\.\d+)?) dB/).flatten.map(&:to_f).max
  end

  # Verify whether the file at the provided path is corrupt.
  # * Regular images: attempt to decode the image with libvips.
  # * GIFs: attempt to decode each frame with libvips.
  # * APNG: not implemented, could defer to ffmpeg if needed.
  # * Other file types: assumed to be non-corrupt.
  def is_corrupt?(file_path)
    return false unless is_image?
    return is_corrupt_gif?(file_path) if is_gif?

    VipsCommand.corrupt?(file_path)
  end
end
