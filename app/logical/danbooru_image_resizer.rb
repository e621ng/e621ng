# frozen_string_literal: true

module DanbooruImageResizer
  module_function

  # https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
  THUMBNAIL_OPTIONS = { size: :down, linear: false, no_rotate: true, export_profile: "srgb", import_profile: "srgb" }.freeze
  # https://www.libvips.org/API/current/VipsForeignSave.html#vips-jpegsave
  JPEG_OPTIONS = { background: 0, strip: true, interlace: true, optimize_coding: true }.freeze
  CROP_OPTIONS = { linear: false, no_rotate: true, export_profile: "srgb", import_profile: "srgb", crop: :attention }.freeze

  def resize(file, width, height, resize_quality = 90)
    output_file = Tempfile.new
    resized_image = thumbnail(file, width, height, THUMBNAIL_OPTIONS)
    resized_image.jpegsave(output_file.path, Q: resize_quality, **JPEG_OPTIONS)

    output_file
  end

  def crop(file, width, height, resize_quality = 90)
    return nil unless Danbooru.config.enable_image_cropping?

    output_file = Tempfile.new
    resized_image = thumbnail(file, width, height, CROP_OPTIONS)
    resized_image.jpegsave(output_file.path, Q: resize_quality, **JPEG_OPTIONS)

    output_file
  end

  # https://github.com/libvips/libvips/wiki/HOWTO----Image-shrinking
  # https://www.libvips.org/API/current/Using-vipsthumbnail.md.html
  def thumbnail(file, width, height, options)
    Vips::Image.thumbnail(file.path, width, height: height, **options)
  rescue Vips::Error => e
    raise e unless e.message =~ /icc_transform/i
    Vips::Image.thumbnail(file.path, width, height: height, **options.except(:import_profile))
  end
end
