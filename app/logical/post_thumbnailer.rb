# frozen_string_literal: true

module PostThumbnailer
  extend self

  def generate_file_preview(file, is_video, bg_color = "000000", origin = { left: 0, top: 0, side: 150 })
    if is_video
      generate_video_preview(file, origin)
    else
      generate_image_preview(file, bg_color, origin)
    end
  end

  def generate_image_preview(file, bg_color = "000000", origin = { left: 0, top: 0, side: 150 })
    r = bg_color[0..1].to_i(16)
    g = bg_color[2..3].to_i(16)
    b = bg_color[4..5].to_i(16)

    scale = (Danbooru.config.small_image_width.to_f / origin[:side])

    output_file = Tempfile.new
    source = Vips::Source.new_from_file(file.path)
    Vips::Image.new_from_source(source, "")
               .crop(origin[:left], origin[:top], origin[:side], origin[:side])
               .resize(scale)
               .jpegsave(output_file.path, Q: 90, background: [r, g, b], strip: true, interlace: true, optimize_coding: true)

    output_file
  end

  def generate_video_preview(file, origin = { left: 0, top: 0, side: 150 })
    output_file = Tempfile.new(["video-preview", ".jpg"], binmode: true)
    # -ss     seeking
    # -y      overwrites output file without asking
    # -i      input file URL
    # -vf     creates filtergraph
    # -frames stop writing after this many frames
    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, "-ss", "1", "-y", "-i", file.path, "-vf", "crop=w=#{origin[:side]}:h=#{origin[:side]}:x=#{origin[:left]}:y=#{origin[:top]},scale=#{Danbooru.config.small_image_width.to_f}:-1", "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG PREVIEW STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG PREVIEW STDERR] #{stderr.chomp!}")
      raise CorruptFileError, "could not generate thumbnail"
    end

    output_file
  end

  def generate_resizes(file, options)
    if options[:type] == :video
      video = FFMPEG::Movie.new(file.path)
      crop_file = generate_video_crop_for(video, Danbooru.config.small_image_width)
      preview_file = generate_video_preview_for(file.path, Danbooru.config.small_image_width)
      sample_file = generate_video_sample_for(file.path)
    elsif options[:type] == :image
      # preview_file = DanbooruImageResizer.resize(file, Danbooru.config.small_image_width, Danbooru.config.small_image_width, 87, background_color: background_color)

      preview_file = DanbooruImageResizer.generate_preview(file, {
        width: Danbooru.config.small_image_width,
        height: Danbooru.config.small_image_width,
        origin: {
          top: options[:origin][:top] || 0,
          left: options[:origin][:left] || 0,
          side: options[:origin][:side] || 150,
        },
        background_color: options[:background_color],
      })
      crop_file = DanbooruImageResizer.crop(file, Danbooru.config.small_image_width, Danbooru.config.small_image_width, 87, background_color: options[:background_color])
      if options[:width] > Danbooru.config.large_image_width
        sample_file = DanbooruImageResizer.resize(file, Danbooru.config.large_image_width, options[:height], 87, background_color: options[:background_color])
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
