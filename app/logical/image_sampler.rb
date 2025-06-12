# frozen_string_literal: true

module ImageSampler
  module_function

  def create_samples_for_post(post)
    image = get_image_from_post(post)
    dimensions = [post.image_width, post.image_height]

    md5 = post.md5
    sm = Danbooru.config.storage_manager

    # Generate thumbnails
    create_thumbnail_from_image(image, dimensions, background: post.bg_color).each do |ext, thumb|
      path = sm.file_path(md5, ext, :preview, post.is_deleted?)
      sm.store(thumb, path)
    ensure
      thumb&.close!
    end

    # Generate a sample
    return unless post.is_video? || post.file_ext == "gif" || dimensions.min > Danbooru.config.large_image_width
    sample = create_sample_from_image(image, dimensions, background: post.bg_color)
    return if sample.nil?

    path = sm.file_path(md5, "jpg", :large, post.is_deleted?)
    sm.store(sample, path)
    sample&.close!
  end

  # Creates a Vips::Image object from the provided post.
  # If the post is a video, it generates a thumbnail using ffmpeg.
  # Otherwise, it loads the image directly from the file path.
  #
  # Parameters:
  #   - post: the post object containing the file path
  #
  # Returns a Vips::Image object.
  def get_image_from_post(post)
    Vips::Image.new_from_file generate_file_path(post)
  end

  # Generates a pair of thumbnails from the provided image.
  # The thumbnail is created by scaling the image to fit within the specified dimensions.
  # If the final image is larger than twice the specified dimensions, it will be cropped.
  #
  # Parameters:
  #   - image: the image to be resized
  #   - dimensions: an array containing the width and height of the final image
  #   - background: the background color to be used (default is "000000")
  #
  # Returns a hash containing the paths to the generated jpg and webp thumbnails.
  # The keys are :jpg and :webp, and the values are Tempfile objects.
  def create_thumbnail_from_image(image, dimensions, background: "000000")
    # scale
    new_scale, crop_area = calculate_dimensions(dimensions[0], dimensions[1], Danbooru.config.small_image_width, crop: true)
    result = image.resize(new_scale)

    # crop
    unless crop_area.nil?
      result = result.smartcrop(crop_area[0], crop_area[1], interesting: :entropy)
    end

    # save
    jpg_thumb = Tempfile.new(["image-thumb", ".jpg"], binmode: true)
    webp_thumb = Tempfile.new(["image-thumb", ".webp"], binmode: true)

    result.jpegsave(jpg_thumb.path, Q: 90, background: parse_background_color(background), strip: true, interlace: true, optimize_coding: true)
    result.webpsave(webp_thumb.path, Q: 90)

    {
      jpg: jpg_thumb,
      webp: webp_thumb,
    }
  end

  # Generates a sample image from the provided image.
  # The sample is created by scaling the image to fit within the specified dimensions.
  # If the final image is larger than twice the specified dimensions, it will be cropped.
  #
  # Parameters:
  #   - image: the image to be resized
  #   - dimensions: an array containing the width and height of the final image
  #   - background: the background color to be used (default is "000000")
  #
  # Returns the path to the generated jpg thumbnail.
  def create_sample_from_image(image, dimensions, background: "000000")
    # scale
    new_scale, _crop_area = calculate_dimensions(dimensions[0], dimensions[1], Danbooru.config.large_image_width)
    result = image.resize(new_scale)

    # save
    jpg_thumb = Tempfile.new(["image-thumb", ".jpg"], binmode: true)
    result.jpegsave(jpg_thumb.path, Q: 90, background: parse_background_color(background), strip: true, interlace: true, optimize_coding: true)

    jpg_thumb
  end

  ###################
  # Utility methods #
  ###################

  # Returns a path to a file that is guaranteed to be an image.
  # If the post is a video, it generates a thumbnail using ffmpeg.
  #
  # Parameters:
  #   - post: the post object containing the file path
  #
  # Returns the path to the generated image file.
  def generate_file_path(post)
    return post.file_path unless post.is_video?

    output_file = Tempfile.new(["video-preview", ".webp"], binmode: true)
    stdout, stderr, status = Open3.capture3(Danbooru.config.ffmpeg_path, "-y", "-i", post.file_path, "-vf", "thumbnail,scale=#{post.image_width}:-1", "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG PREVIEW STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG PREVIEW STDERR] #{stderr.chomp!}")
      raise CorruptFileError, "could not generate thumbnail"
    end

    output_file.close
    output_file.path
  end

  # Calculates the dimensions of the generated image.
  #
  # Parameters:
  #   - width: the width of the original image
  #   - height: the height of the original image
  #   - limit: the maximum width or height of the final image
  #   - crop: whether to crop the final image to fit the limit
  #
  # Returns an array containing the new scale and the crop area (if applicable).
  def calculate_dimensions(width, height, limit, crop: false)
    limit = limit.to_f
    if width < height # vertical
      new_scale = limit / width
      crop_area = [limit, limit * 2] if crop && height * new_scale > limit * 2
    elsif width > height # horizontal
      new_scale = limit / height
      crop_area = [limit * 2, limit] if crop && width * new_scale > limit * 2
    else # square
      new_scale = limit / width
    end

    [new_scale, crop_area]
  end

  # Converts a hex color string to an array of RGB values.
  #
  # Parameters:
  #   - hex_color: a string representing the hex color (e.g., "#000000")
  #
  # Returns an array of RGB values (e.g., [0, 0, 0])
  def parse_background_color(hex_color = "152f56")
    hex_color = hex_color.blank? ? "152f56" : hex_color.delete("#")
    r = hex_color[0..1].to_i(16)
    g = hex_color[2..3].to_i(16)
    b = hex_color[4..5].to_i(16)
    [r, g, b]
  end
end
