# frozen_string_literal: true

module ImageSampler
  SNAPSHOT_TIMEOUT = 45

  module_function

  def generate_post_images(post)
    return unless File.exist?(post.file_path)
    return if post.is_flash? # Cannot generate any kind of thumbnail

    with_still_image(post.file_path, is_video: post.is_video?) do |source_path|
      # Read from the file – stored post dimensions may predate EXIF autorotation and be swapped.
      dimensions = oriented_dimensions(source_path)

      sm = Danbooru.config.storage_manager

      # Generate thumbnails
      thumbnail(source_path, dimensions, background: post.bg_color).each do |ext, file|
        path = sm.post_file_path(post, :"preview_#{ext}")
        sm.store(file, path)
      ensure
        file&.close!
      end

      # Generate samples
      # Animated GIFs, APNGs, and WEBPs are not needed, Flash files are not supported.
      # All video files need samples to be used as a poster in the player.
      return if post.is_gif? || post.is_animated_png?(post.file_path) || post.is_animated_webp?(post.file_path)
      return unless post.is_video? || dimensions.min > Danbooru.config.large_image_width || dimensions.max > Danbooru.config.large_image_width * 2
      sample(source_path, dimensions, background: post.bg_color).each do |ext, file|
        path = sm.post_file_path(post, :"sample_#{ext}")
        sm.store(file, path)
      ensure
        file&.close!
      end
    end
  end

  def generate_avatar_crop(post, user_id, pos_x:, pos_y:, width:)
    sm = Danbooru.config.storage_manager
    source_path = post.has_sample? ? sm.post_file_path(post, :sample_jpg) : post.file_path
    # Crop coordinates come from the browser, which displays the original with EXIF orientation applied.
    image = Vips::Image.new_from_file(source_path).autorot

    cropped = image.crop(pos_x, pos_y, width, width)
    target = Danbooru.config.small_image_width
    resized = cropped.resize(target.to_f / width)

    jpg = Tempfile.new(["avatar", ".jpg"], binmode: true)
    webp = Tempfile.new(["avatar", ".webp"], binmode: true)

    resized.jpegsave(
      jpg.path,
      Q: 90,
      strip: true,
      interlace: true,
      optimize_coding: true,
      optimize_scans: true,
      trellis_quant: true,
      quant_table: 3,
    )
    resized.webpsave(
      webp.path,
      Q: 90,
      effort: 6,
      alpha_q: 90,
      smart_subsample: true,
    )

    sm.store_avatar(jpg, user_id, "jpg")
    sm.store_avatar(webp, user_id, "webp")
  ensure
    jpg&.close!
    webp&.close!
  end

  def generate_replacement_images(replacement)
    return unless File.exist?(replacement.replacement_file_path)
    return if replacement.file_ext == "swf" # Cannot generate any kind of thumbnail

    with_still_image(replacement.replacement_file_path, is_video: replacement.is_video?) do |source_path|
      # Generate thumbnails
      thumb, webp = thumbnail(source_path, oriented_dimensions(source_path)).values_at(:jpg, :webp)
      webp&.close!
      Danbooru.config.storage_manager.store_replacement(thumb, replacement, :preview)
      thumb&.close!
    end
  end

  # Yields the path of a still image of the file: the file itself, or for a video,
  # a snapshot generated with ffmpeg that is deleted afterwards.
  def with_still_image(file_path, is_video: false)
    return yield(file_path) unless is_video

    snapshot = gen_video_snapshot(file_path)
    yield snapshot.path
  ensure
    snapshot&.close!
  end

  # Width and height as browsers display the image, with EXIF orientation applied.
  # Only reads the header.
  def oriented_dimensions(file_path)
    image = Vips::Image.new_from_file(file_path)
    orientation = image.get_typeof("orientation") == 0 ? 1 : image.get("orientation")
    orientation.between?(5, 8) ? [image.height, image.width] : [image.width, image.height]
  end

  # Generates a pair of thumbnails from the image file.
  # Parameters:
  #   - file_path: the image to be resized
  #   - dimensions: the image's width and height, as displayed (see oriented_dimensions)
  #   - background: the background color to be used
  # Returns a hash containing the paths to the generated jpg and webp thumbnails.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def thumbnail(file_path, dimensions, background: "000000")
    gen_target_image(file_path, dimensions, Danbooru.config.small_image_width, crop: true, background: background)
  end

  # Generates a sample image from the image file.
  # Parameters:
  #   - file_path: the image to be resized
  #   - dimensions: the image's width and height, as displayed (see oriented_dimensions)
  #   - background: the background color to be used
  # Returns a hash containing the paths to the generated jpg and webp samples.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def sample(file_path, dimensions, background: "000000")
    gen_target_image(file_path, dimensions, Danbooru.config.large_image_width, crop: false, background: background)
  end

  ### Utility Methods ###

  # Generates a snapshot of the first frame of a video file using ffmpeg.
  # Parameters:
  #   - file_path: the path to the video file
  # Returns the path to the generated snapshot file.
  def gen_video_snapshot(file_path)
    output_file = Tempfile.new(["video-preview", ".png"], binmode: true)
    decoder_args = video_alpha_decoder_args(file_path)
    stdout, stderr, status = ExternalCommand.run(Danbooru.config.ffmpeg_path, "-y", *decoder_args, "-threads", "2", "-filter_threads", "1", "-i", file_path, "-vf", video_snapshot_filter(file_path), "-frames:v", "1", output_file.path, timeout: SNAPSHOT_TIMEOUT)

    unless status == 0
      Rails.logger.warn("[FFMPEG PREVIEW STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG PREVIEW STDERR] #{stderr.chomp!}")
      raise "Could not generate video snapshot"
    end

    output_file.close
    output_file
  end

  # Returns the ffmpeg input decoder arguments needed to preserve alpha for VP8/VP9
  # WebM files. Both codecs store alpha as a secondary bitstream tagged with
  # alpha_mode=1; the native FFmpeg decoders ignore it, only the libvpx variants
  # decode it correctly.
  def video_alpha_decoder_args(file_path)
    stdout, _stderr, status = ExternalCommand.run(
      Danbooru.config.ffprobe_path, "-v", "error",
      "-select_streams", "v:0",
      "-show_entries", "stream=codec_name:stream_tags=alpha_mode",
      "-of", "default=noprint_wrappers=1",
      file_path,
      timeout: FileMethods::FFPROBE_TIMEOUT
    )
    return [] unless status == 0

    has_alpha = stdout.include?("alpha_mode=1")
    return [] unless has_alpha

    if stdout.include?("codec_name=vp9")
      ["-vcodec", "libvpx-vp9"]
    elsif stdout.include?("codec_name=vp8")
      ["-vcodec", "libvpx"]
    else
      []
    end
  end

  # YCbCr matrices that FFmpeg's automatic scaler (swscale) can convert from.
  # Anything else makes it refuse to build the snapshot filter graph.
  SWSCALE_SUPPORTED_MATRICES = %w[unknown gbr bt709 fcc bt470bg smpte170m smpte240m bt2020nc].freeze

  # Returns a `setparams` filter that relabels the video's YCbCr matrix to bt709, or nil when no
  # relabelling is needed. Some files are mistagged with an exotic colour space (e.g. ICtCp, which
  # cannot pair with 8-bit yuv420p) that swscale can't convert from; it then aborts with "Impossible
  # to convert between the formats supported by the filter". Relabelling the matrix — without
  # touching the pixel data — lets the filter graph be built.
  # The colours may be slightly off, but this is preferable to no snapshot at all.
  def colorspace_relabel_filter(file_path)
    colorspace = video_colorspace(file_path)
    return nil if colorspace.blank? || SWSCALE_SUPPORTED_MATRICES.include?(colorspace)

    Rails.logger.warn("[ImageSampler] unsupported colour space #{colorspace.inspect} in #{file_path}, relabelling to bt709")
    "setparams=colorspace=bt709"
  end

  # Returns the `-vf` filter chain for the snapshot.
  # `thumbnail` holds 100 frames to pick from, so frames are first shrunk to the largest
  # size a sample can use (twice large_image_width on the long side). Never upscales.
  def video_snapshot_filter(file_path)
    box = Danbooru.config.large_image_width * 2
    scale = "scale='min(iw,#{box})':'min(ih,#{box})':force_original_aspect_ratio=decrease:flags=lanczos"
    [colorspace_relabel_filter(file_path), scale, "thumbnail"].compact.join(",")
  end

  # Returns the video stream's tagged YCbCr matrix (e.g. "bt709", "ictcp"),
  # or an empty string if it can't be determined.
  def video_colorspace(file_path)
    stdout, _stderr, status = ExternalCommand.run(
      Danbooru.config.ffprobe_path, "-v", "error",
      "-select_streams", "v:0",
      "-show_entries", "stream=color_space",
      "-of", "default=noprint_wrappers=1:nokey=1",
      file_path,
      timeout: FileMethods::FFPROBE_TIMEOUT
    )
    return "" unless status == 0

    stdout.strip
  end

  # Calculates the dimensions of the generated image.
  # Parameters:
  #   - width: the width of the original image
  #   - height: the height of the original image
  #   - limit: the maximum width or height of the final image
  #   - crop: whether to crop the final image to fit the limit
  # Returns an array containing the new scale and the crop area (if applicable).
  def calc_dimensions(width, height, limit, crop: false)
    return calc_dimensions_for_preview(width, height, limit) if crop
    calc_dimensions_for_sample(width, height, limit)
  end

  def calc_dimensions_for_preview(width, height, limit = Danbooru.config.small_image_width)
    limit = limit.to_f
    if width < height # vertical
      new_scale = limit / width
      crop_area = [limit.to_i, (limit * 2).to_i] if height * new_scale > limit * 2
    elsif width > height # horizontal
      new_scale = limit / height
      crop_area = [(limit * 2).to_i, limit.to_i] if width * new_scale > limit * 2
    else # square
      new_scale = limit / width
    end

    [new_scale, crop_area]
  end

  def calc_dimensions_for_sample(width, height, limit = Danbooru.config.large_image_width)
    limit = limit.to_f
    if width < height # vertical
      new_scale = limit / width
      if height * new_scale > limit * 2
        new_scale = (limit * 2) / height
      end
    elsif width > height # horizontal
      new_scale = limit / height
      if width * new_scale > limit * 2
        new_scale = (limit * 2) / width
      end
    else # square
      new_scale = limit / width
    end

    [new_scale, nil]
  end

  # Converts a hex color string to an array of RGB values.
  # Parameters:
  #   - hex_color: a string representing the hex color (e.g., "#000000")
  # Returns an array of RGB values (e.g., [0, 0, 0])
  def calc_background_color(hex_color = nil)
    hex_color = hex_color.blank? ? Danbooru.config.default_bg_color : hex_color.delete("#")
    r = hex_color[0..1].to_i(16)
    g = hex_color[2..3].to_i(16)
    b = hex_color[4..5].to_i(16)
    [r, g, b]
  end

  # Generates a pair of samples from the image file.
  # A sample is created by scaling the image to fit within the specified dimensions.
  # If the final image is larger than twice the specified dimensions, it will be cropped.
  #
  # Parameters:
  #   - file_path: the image to be resized
  #   - original_dims: the image's width and height, as displayed
  #   - target_side: the maximum width or height of the final image
  #   - background: the background color to be used
  #
  # Returns a hash containing the paths to the generated jpg and webp thumbnails.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def gen_target_image(file_path, original_dims, target_size, crop: false, background: "000000")
    new_scale, crop_area = calc_dimensions(original_dims[0], original_dims[1], target_size, crop: crop)
    width, height = crop_area || original_dims.map { |side| [(side * new_scale).round, 1].max }

    # thumbnail shrinks while loading where the format allows it, and applies the EXIF
    # orientation after shrinking, so the full-size image is never held in memory.
    # When cropping it scales to cover the box, then crops the least interesting edges.
    result = Vips::Image.thumbnail(file_path, width, height: height, crop: crop_area ? :entropy : :none)

    # Convert embedded colour spaces to sRGB for compatibility.
    if result.get_typeof("icc-profile-data") != 0
      begin
        result = result.icc_transform("srgb", intent: :perceptual)
      rescue Vips::Error => e
        Rails.logger.warn("[ImageSampler] icc_transform failed, stripping profile: #{e.message}")
      end
    end

    # save
    # The source is read sequentially, so keep the small result in memory for the two saves.
    result = result.copy_memory
    jpg_image = Tempfile.new(["image-thumb", ".jpg"], binmode: true)
    webp_image = Tempfile.new(["image-thumb", ".webp"], binmode: true)

    result.jpegsave(
      jpg_image.path,
      Q: 90,
      background: calc_background_color(background),
      strip: true,
      interlace: true,
      optimize_coding: true,
      optimize_scans: true,
      trellis_quant: true,
      quant_table: 3,
    )
    result.webpsave(
      webp_image.path,
      Q: 90,
      effort: 6,
      alpha_q: 90,
      smart_subsample: true,
    )

    {
      jpg: jpg_image,
      webp: webp_image,
    }
  end
end
