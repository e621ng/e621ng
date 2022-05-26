module DanbooruImageResizer
  extend self

  # Taken from ArgyllCMS 2.0.0 (see also: https://ninedegreesbelow.com/photography/srgb-profile-comparison.html)
  SRGB_PROFILE = "#{Rails.root}/config/sRGB.icm"
  # https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
  THUMBNAIL_OPTIONS = { size: :down, linear: false, no_rotate: true, export_profile: SRGB_PROFILE, import_profile: SRGB_PROFILE }
  THUMBNAIL_OPTIONS_NO_ICC = { size: :down, linear: false, no_rotate: true, export_profile: SRGB_PROFILE }
  # https://www.libvips.org/API/current/VipsForeignSave.html#vips-jpegsave
  JPEG_OPTIONS = { background: 0, strip: true, interlace: true, optimize_coding: true }
  CROP_OPTIONS = { linear: false, no_rotate: true, export_profile: SRGB_PROFILE, import_profile: SRGB_PROFILE, crop: :attention }
  CROP_OPTIONS_NO_ICC = { linear: false, no_rotate: true, export_profile: SRGB_PROFILE, crop: :attention }

  # https://github.com/libvips/libvips/wiki/HOWTO----Image-shrinking
  # https://www.libvips.org/API/current/Using-vipsthumbnail.md.html
  def resize(file, width, height, resize_quality = 90)
    output_file = Tempfile.new
    begin
      resized_image = Vips::Image.thumbnail(file.path, width, height: height, **THUMBNAIL_OPTIONS)
    rescue Vips::Error => e
      raise e unless e.message =~ /icc_transform/i
      resized_image = Vips::Image.thumbnail(file.path, width, height: height, **THUMBNAIL_OPTIONS_NO_ICC)
    end
    resized_image.jpegsave(output_file.path, Q: resize_quality, **JPEG_OPTIONS)

    output_file
  end

  def crop(file, width, height, resize_quality = 90)
    return nil unless Danbooru.config.enable_image_cropping?

    output_file = Tempfile.new
    begin
      resized_image = Vips::Image.thumbnail(file.path, width, height: height, **CROP_OPTIONS)
    rescue Vips::Error => e
      raise e unless e.message =~ /icc_transform/i
      resized_image = Vips::Image.thumbnail(file.path, width, height: height, **CROP_OPTIONS_NO_ICC)
    end
    resized_image.jpegsave(output_file.path, Q: resize_quality, **JPEG_OPTIONS)

    output_file
  end
end
