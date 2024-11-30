# frozen_string_literal: true

module DanbooruImageResizer
  module_function

  # https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
  THUMBNAIL_OPTIONS = { size: :down, linear: false, no_rotate: true, export_profile: "srgb", import_profile: "srgb" }.freeze
  # https://www.libvips.org/API/current/VipsForeignSave.html#vips-jpegsave
  JPEG_OPTIONS = { strip: true, interlace: true, optimize_coding: true }.freeze
  CROP_OPTIONS = { linear: false, no_rotate: true, export_profile: "srgb", import_profile: "srgb", crop: :attention }.freeze

  def generate_preview(file, options)
    options[:width] = options[:width] || Danbooru.config.small_image_width
    options[:height] = options[:height] || Danbooru.config.small_image_width
    options[:background_color] = options[:background_color] || "000000"

    r = options[:background_color][0..1].to_i(16)
    g = options[:background_color][2..3].to_i(16)
    b = options[:background_color][4..5].to_i(16)
    output_file = Tempfile.new

    scale = (Danbooru.config.small_image_width.to_f / options[:origin][:side]).round(2)
    puts ["\nSCALE", Danbooru.config.small_image_width, options[:origin][:side], scale].join(" ")

    source = Vips::Source.new_from_file(file.path)
    Vips::Image.new_from_source(source, "")
               .crop(options[:origin][:left], options[:origin][:top], options[:origin][:side], options[:origin][:side])
               .resize(scale)
               .jpegsave(output_file.path, Q: 90, background: [r, g, b], **JPEG_OPTIONS)
    # image.thumbnail(Danbooru.config.small_image_width, height: Danbooru.config.small_image_width, **THUMBNAIL_OPTIONS)

    puts ["\nVIPS", options[:origin][:left], options[:origin][:top], options[:origin][:side], options[:origin][:side]].join(" ")

    output_file
  rescue Vips::Error => e # rubocop:disable Lint/UselessRescue
    raise e
  end

  def resize(file, width, height, resize_quality = 90, background_color: "000000")
    background_color = background_color.presence || "000000"
    r = background_color[0..1].to_i(16)
    g = background_color[2..3].to_i(16)
    b = background_color[4..5].to_i(16)
    output_file = Tempfile.new
    resized_image = thumbnail(file, width, height, THUMBNAIL_OPTIONS)
    resized_image.jpegsave(output_file.path, Q: resize_quality, background: [r, g, b], **JPEG_OPTIONS)

    output_file
  end

  def crop(file, width, height, resize_quality = 90, background_color: "000000")
    background_color = background_color.presence || "000000"
    return nil unless Danbooru.config.enable_image_cropping?

    r = background_color[0..1].to_i(16)
    g = background_color[2..3].to_i(16)
    b = background_color[4..5].to_i(16)
    output_file = Tempfile.new
    resized_image = thumbnail(file, width, height, CROP_OPTIONS)
    resized_image.jpegsave(output_file.path, Q: resize_quality, background: [r, g, b], **JPEG_OPTIONS)

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
