# frozen_string_literal: true

# Builds and inspects image files through the libvips CLI (see VipsCommand), since the
# app no longer links libvips in-process.
module VipsHelpers
  # Writes a solid-colour 8-bit sRGB image to +path+ (the saver is picked from its extension).
  def write_solid_image(path, width, height, color: [128, 128, 128])
    Tempfile.create(["solid", ".v"]) do |black|
      Tempfile.create(["solid", ".v"]) do |solid|
        VipsCommand.operation("black", black.path, width, height, bands: color.size, timeout: 10)
        VipsCommand.operation("linear", black.path, solid.path, [1] * color.size, color, uchar: true, timeout: 10)
        VipsCommand.operation("copy", solid.path, path, interpretation: "srgb", timeout: 10)
      end
    end
    path
  end

  # Writes an sRGB-coloured image converted to and tagged with a Display P3 profile, so the
  # stored pixel values differ from +color+ until the profile is applied.
  def write_p3_image(path, width, height, color:)
    Tempfile.create(["p3", ".v"]) do |srgb|
      write_solid_image(srgb.path, width, height, color: color)
      VipsCommand.operation("icc_transform", srgb.path, path, "p3", input_profile: "srgb", timeout: 10)
    end
    path
  end

  def image_dimensions(path)
    VipsCommand.dimensions(path)
  end

  def image_bands(path)
    VipsCommand.header(path)["bands"].to_i
  end

  def pixel_at(path, left, top)
    VipsCommand.getpoint(path, left, top)
  end

  # [min, max] of one band.
  def band_range(path, band)
    Tempfile.create(["band", ".v"]) do |extracted|
      VipsCommand.operation("extract_band", path, extracted.path, band, timeout: 10)
      [VipsCommand.operation("min", extracted.path, timeout: 10).to_f, VipsCommand.operation("max", extracted.path, timeout: 10).to_f]
    end
  end
end

RSpec.configure do |config|
  config.include VipsHelpers
end
