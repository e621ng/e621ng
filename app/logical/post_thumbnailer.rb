# frozen_string_literal: true

module PostThumbnailer
  extend self
  def generate_resizes(file, height, width, type)
    if type == :video
      video = FFMPEG::Movie.new(file.path)
      crop_file = generate_video_crop_for(video, Danbooru.config.small_image_width)
      preview_file = generate_video_preview_for(file.path, Danbooru.config.small_image_width)
      sample_file = generate_video_sample_for(file.path)
    elsif type == :image
      preview_file = DanbooruImageResizer.resize(file, Danbooru.config.small_image_width, Danbooru.config.small_image_width, 87)
      crop_file = DanbooruImageResizer.crop(file, Danbooru.config.small_image_width, Danbooru.config.small_image_width, 87)
      if width > Danbooru.config.large_image_width
        sample_file = DanbooruImageResizer.resize(file, Danbooru.config.large_image_width, height, 87)
      end
    end

    [preview_file, crop_file, sample_file]
  end

  def generate_thumbnail(file, type)
    if type == :video
      preview_file = generate_video_preview_for(file.path, Danbooru.config.small_image_width)
    elsif type == :image
      preview_file = DanbooruImageResizer.resize(file, Danbooru.config.small_image_width, Danbooru.config.small_image_width, 87)
    end

    preview_file
  end

  def generate_video_crop_for(video, width)
    vp = Tempfile.new(["video-preview", ".jpg"], binmode: true)
    video.screenshot(vp.path, {:seek_time => 0, :resolution => "#{video.width}x#{video.height}"})
    crop = DanbooruImageResizer.crop(vp, width, width, 87)
    vp.close
    return crop
  end

  def generate_video_preview_for(video, width)
    output_file = Tempfile.new(["video-preview", ".jpg"], binmode: true)
    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, '-y', '-i', video, '-vf', "thumbnail,scale=#{width}:-1", '-frames:v', '1', output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG PREVIEW STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG PREVIEW STDERR] #{stderr.chomp!}")
      raise CorruptFileError.new("could not generate thumbnail")
    end
    output_file
  end

  def generate_video_sample_for(video)
    output_file = Tempfile.new(["video-sample", ".jpg"], binmode: true)
    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, '-y', '-i', video, '-vf', 'thumbnail', '-frames:v', '1', output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG SAMPLE STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG SAMPLE STDERR] #{stderr.chomp!}")
      raise CorruptFileError.new("could not generate sample")
    end
    output_file
  end
end
