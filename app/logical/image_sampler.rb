# frozen_string_literal: true

module ImageSampler
  module_function

  def generate_post_images(post)
    return unless File.exist?(post.file_path)
    return if post.is_flash? # Cannot generate any kind of thumbnail
    image = image_from_path(post.file_path, is_video: post.is_video?)
    dimensions = [post.image_width, post.image_height]

    sm = Danbooru.config.storage_manager

    # Generate thumbnails
    thumbnail(image, dimensions, background: post.bg_color).each do |ext, file|
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
    sample(image, dimensions, background: post.bg_color).each do |ext, file|
      path = sm.post_file_path(post, :"sample_#{ext}")
      sm.store(file, path)
    ensure
      file&.close!
    end
  end

  def generate_replacement_images(replacement)
    return unless File.exist?(replacement.replacement_file_path)
    return if replacement.file_ext == "swf" # Cannot generate any kind of thumbnail
    image = image_from_path(replacement.replacement_file_path, is_video: replacement.is_video?)
    dimensions = [replacement.image_width, replacement.image_height]

    # Generate thumbnails
    thumb = thumbnail(image, dimensions)[:jpg]
    Danbooru.config.storage_manager.store_replacement(thumb, replacement, :preview)
    thumb&.close!
  end

  # Creates a Vips::Image object from the provided file path.
  # If the file is a video, generates a snapshot using ffmpeg.
  def image_from_path(file_path, is_video: false)
    file_path = gen_video_snapshot(file_path) if is_video
    Vips::Image.new_from_file file_path
  end

  # Generates a pair of thumbnails from the provided image.
  # Parameters:
  #   - image: the image to be resized
  #   - dimensions: an array containing the width and height of the final image
  #   - background: the background color to be used
  # Returns a hash containing the paths to the generated jpg and webp thumbnails.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def thumbnail(image, dimensions, background: "000000")
    gen_target_image(image, dimensions, Danbooru.config.small_image_width, crop: true, background: background)
  end

  def thumbnail_from_path(file_path, dimensions, background: "000000", is_video: false)
    thumbnail(image_from_path(file_path, is_video: is_video), dimensions, background: background)
  end

  # Generates a sample image from the provided image.
  # Parameters:
  #   - image: the image to be resized
  #   - dimensions: an array containing the width and height of the final image
  #   - background: the background color to be used
  # Returns a hash containing the paths to the generated jpg and webp samples.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def sample(image, dimensions, background: "000000")
    gen_target_image(image, dimensions, Danbooru.config.large_image_width, crop: false, background: background)
  end

  def sample_from_path(file_path, dimensions, background: "000000", is_video: false)
    sample(image_from_path(file_path, is_video: is_video), dimensions, background: background)
  end

  ### Utility Methods ###

  # Generates a snapshot of the first frame of a video file using ffmpeg.
  # Parameters:
  #   - file_path: the path to the video file
  # Returns the path to the generated snapshot file.
  def gen_video_snapshot(file_path)
    output_file = Tempfile.new(["video-preview", ".jpg"], binmode: true)
    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, "-y", "-i", file_path, "-vf", "thumbnail", "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG PREVIEW STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG PREVIEW STDERR] #{stderr.chomp!}")
      raise "Could not generate video snapshot"
    end

    output_file.close
    output_file.path
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
  def calc_background_color(hex_color = "152f56")
    hex_color = hex_color.blank? ? "152f56" : hex_color.delete("#")
    r = hex_color[0..1].to_i(16)
    g = hex_color[2..3].to_i(16)
    b = hex_color[4..5].to_i(16)
    [r, g, b]
  end

  # Generates a pair of samples from the provided image.
  # A sample is created by scaling the image to fit within the specified dimensions.
  # If the final image is larger than twice the specified dimensions, it will be cropped.
  #
  # Parameters:
  #   - image: the image to be resized
  #   - original_dims: an array containing the original width and height of the image
  #   - target_side: the maximum width or height of the final image
  #   - background: the background color to be used
  #
  # Returns a hash containing the paths to the generated jpg and webp thumbnails.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def gen_target_image(image, original_dims, target_size, crop: false, background: "000000")
    # scale
    new_scale, crop_area = calc_dimensions(original_dims[0], original_dims[1], target_size, crop: crop)
    result = image.resize(new_scale)

    # crop
    unless crop_area.nil?
      result = result.smartcrop(crop_area[0], crop_area[1], interesting: :entropy)
    end

    # save
    jpg_image = Tempfile.new(["image-thumb", ".jpg"], binmode: true)
    webp_image = Tempfile.new(["image-thumb", ".webp"], binmode: true)

    result.jpegsave(jpg_image.path, Q: 90, background: calc_background_color(background), strip: true, interlace: true, optimize_coding: true)
    result.webpsave(webp_image.path, Q: 90, min_size: true)

    {
      jpg: jpg_image,
      webp: webp_image,
    }
  end
end
