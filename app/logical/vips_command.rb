# frozen_string_literal: true

# Runs libvips as a child process through ExternalCommand instead of in-process through
# ruby-vips, so untrusted images get the same time, CPU, memory and environment limits as
# ffmpeg, and a crash in a loader can't take the Rails worker down with it.
# Results are plain Ruby values; intermediate images are passed between steps as .v files.
module VipsCommand
  class Error < StandardError; end
  class UnsupportedFormat < Error; end

  HEADER_TIMEOUT = 10
  DECODE_TIMEOUT = 60
  SAVE_TIMEOUT = 30

  # Every operation that reads an uploaded file goes through check_format!, which only lets
  # the formats we accept past, and runs with VIPS_BLOCK_UNTRUSTED, which disables the
  # loaders libvips itself considers unsafe (SVG, PPM, TIFF, FITS, ...) in case a call ever
  # bypasses the gate. That also disables the .v loader, so steps that read our own
  # intermediate images run without it.
  ALLOWED_MIME_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  # libvips defaults to nproc threads per operation, in every web worker and job thread.
  # VIPS_CONCURRENCY in the environment overrides this per container.
  ENVIRONMENT = {
    "VIPS_WARNING" => "0",
    "VIPS_CONCURRENCY" => ENV.fetch("VIPS_CONCURRENCY", "1"),
  }.freeze
  UNTRUSTED_ENVIRONMENT = ENVIRONMENT.merge("VIPS_BLOCK_UNTRUSTED" => "1").freeze

  # VIPS file format: a 64-byte header of native-endian int32s, then raw interleaved pixels.
  V_MAGIC = 0x08f2a6b6
  V_HEADER_SIZE = 64
  V_FORMAT_UCHAR = 0

  module_function

  def check_format!(file_path)
    mime_type = File.open(file_path, "rb") { |file| Marcel::MimeType.for(file) }
    raise UnsupportedFormat, "#{mime_type} is not a supported image format" unless ALLOWED_MIME_TYPES.include?(mime_type)
  rescue SystemCallError => e
    raise Error, "#{file_path} is unreadable: #{e.message}"
  end

  # All metadata fields as strings, keyed by name. Only the first line of a multi-line
  # value is listed, and binary fields such as exif-data read "N bytes of binary data";
  # use header_field for their contents.
  def header(file_path)
    check_format!(file_path)
    stdout = run(Danbooru.config.vipsheader_path, "-a", file_path, timeout: HEADER_TIMEOUT, env: UNTRUSTED_ENVIRONMENT)

    # The first line summarises the image.
    stdout.scrub.lines.drop(1).filter_map do |line|
      name, value = line.chomp.split(": ", 2)
      [name, value] if value
    end.to_h
  end

  # The full value of one field, or nil when the image has no such field.
  def header_field(file_path, field, binary: false)
    check_format!(file_path)
    stdout, _stderr, status = ExternalCommand.run(Danbooru.config.vipsheader_path, "-f", field, file_path, env: UNTRUSTED_ENVIRONMENT, timeout: HEADER_TIMEOUT)
    return nil unless status.success?

    binary ? Base64.decode64(stdout) : stdout.chomp
  rescue ExternalCommand::TimeoutError => e
    raise Error, e.message
  end

  # Width and height as browsers display the image, with EXIF orientation applied.
  # Only reads the header.
  def dimensions(file_path)
    fields = header(file_path)
    width = fields["width"].to_i
    height = fields["height"].to_i
    fields["orientation"].to_i.between?(5, 8) ? [height, width] : [width, height]
  end

  def animated_gif?(file_path)
    header(file_path)["n-pages"].to_i > 1
  end

  # Decodes the image (every frame with all_frames) and reports whether libvips hit an error.
  def corrupt?(file_path, all_frames: false)
    check_format!(file_path)
    options = ["fail-on=error"]
    options << "n=-1" if all_frames
    Tempfile.create(["vips-stats", ".csv"]) do |output|
      operation("stats", "#{file_path}[#{options.join(',')}]", output.path, timeout: DECODE_TIMEOUT, untrusted: true)
    end
    false
  rescue Error
    true
  end

  # Shrinks the image to fit width x height (or to exactly that with size: :force), applying
  # the EXIF orientation and converting any embedded colour profile to sRGB. Shrinks while
  # loading where the format allows it, so the full-size image is never held in memory.
  # Returns a Tempfile holding a .v image.
  def thumbnail(file_path, width, height:, crop: :none, size: :both)
    check_format!(file_path)
    with_output do |output|
      operation("thumbnail", file_path, output.path, width, height: height, crop: crop, size: size, export_profile: "srgb", intent: "perceptual", timeout: DECODE_TIMEOUT, untrusted: true)
    end
  end

  # The image with its EXIF orientation applied, as a .v Tempfile.
  def autorot(file_path)
    check_format!(file_path)
    with_output { |output| operation("autorot", file_path, output.path, timeout: DECODE_TIMEOUT, untrusted: true) }
  end

  # Runs a saver such as jpegsave or webpsave with the given options.
  def save(saver, image_path, out_path, **)
    operation(saver, image_path, out_path, timeout: SAVE_TIMEOUT, **)
    nil
  end

  # Band values of one pixel.
  def getpoint(file_path, left, top)
    check_format!(file_path)
    operation("getpoint", file_path, left, top, timeout: DECODE_TIMEOUT, untrusted: true).split.map(&:to_i)
  end

  # Pixels of a .v image as 8-bit values: { width:, height:, bands:, pixels: binary String }.
  def read_v(v_path)
    data = File.binread(v_path)
    magic, width, height, bands, _bits, format = data.unpack("L<6")
    raise Error, "#{v_path} is not a vips image" unless magic == V_MAGIC

    if format != V_FORMAT_UCHAR
      return Tempfile.create(["vips-cast", ".v"]) do |output|
        operation("cast", v_path, output.path, "uchar", shift: true, timeout: SAVE_TIMEOUT)
        read_v(output.path)
      end
    end

    { width: width, height: height, bands: bands, pixels: data.byteslice(V_HEADER_SIZE, width * height * bands) }
  end

  # Runs `vips <name> args... --option value ...`. Boolean options become bare flags, arrays
  # (vectors) are joined with spaces, underscores become dashes. Returns stdout.
  # Pass untrusted: true when the input is an uploaded file rather than our own intermediate.
  def operation(name, *args, timeout:, untrusted: false, **options)
    flags = options.compact.flat_map do |key, value|
      flag = "--#{key.to_s.tr('_', '-')}"
      case value
      when true then [flag]
      when false then []
      else [flag, argument(value)]
      end
    end
    run(Danbooru.config.vips_path, name, *args.map { |arg| argument(arg) }, *flags, timeout: timeout, env: untrusted ? UNTRUSTED_ENVIRONMENT : ENVIRONMENT)
  end

  def argument(value)
    value.is_a?(Array) ? value.join(" ") : value.to_s
  end

  def run(*argv, timeout:, env:)
    stdout, stderr, status = ExternalCommand.run(*argv, env: env, timeout: timeout)
    return stdout if status.success?

    message = stderr.scrub.strip.lines.last(3).join.strip.presence || "#{File.basename(argv.first)} exited with status #{status.exitstatus}"
    Rails.logger.warn("[VipsCommand] #{argv.join(' ')}: #{message}")
    raise Error, message
  rescue ExternalCommand::TimeoutError => e
    Rails.logger.warn("[VipsCommand] #{e.message}")
    raise Error, e.message
  end

  # Yields a .v Tempfile for an operation to write to and returns it, or closes it on failure.
  def with_output
    output = Tempfile.new(["vips", ".v"], binmode: true)
    yield(output)
    output
  rescue StandardError
    output&.close!
    raise
  end

  private_class_method :run, :argument, :with_output
end
