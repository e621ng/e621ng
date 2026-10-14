# frozen_string_literal: true

module AiMethods
  # Known generator and platform markers
  AI_GENERATORS = [
    "novelai", "nai", "stable diffusion", "sdxl", "automatic1111", "a1111",
    "comfyui", "invokeai", "midjourney", "dall·e", "dall-e", "openai",
    "bing image creator", "firefly", "adobe generative fill", "adobe firefly",
    "leonardo", "playground", "google generative ai", "synthid",
  ].freeze

  # Parameter/telltale tokens commonly embedded in PNG/JPEG comments or EXIF
  SD_TOKENS = [
    "negative prompt:", "steps:", "sampler:", "cfg scale:", "model hash",
    "hires fix", "denoising strength", "clip skip", "refiner:",
    '"sampler":', '"seed":', '"model":', '"workflow":', "sd-metadata",
    "comfy", "parameters:", "seed:", "sampler:", "cfg:", "hires:",
  ].freeze

  # C2PA / Content Credentials indicators (usually in XMP/JUMBF)
  C2PA_TOKENS = ["c2pa.org", "jumbf", "manifeststore", "c2pa"].freeze

  CAMERA_TOKENS = %w[Make Model DateTimeOriginal ExposureTime FNumber ISO].freeze

  def self.build_token_regex(tokens)
    patterns = tokens.map do |token|
      if token.include?(" ") || token.match?(/[^a-z0-9]/)
        Regexp.escape(token)
      else
        "\\b#{Regexp.escape(token)}\\b" # Prevent substring matches
      end
    end
    Regexp.new(patterns.join("|"), Regexp::IGNORECASE)
  end

  AI_GENERATORS_REGEX = build_token_regex(AI_GENERATORS)
  SD_TOKENS_REGEX = build_token_regex(SD_TOKENS)
  C2PA_TOKENS_REGEX = build_token_regex(C2PA_TOKENS)

  # IPTC digitalSourceType values that declare AI generation in a C2PA manifest
  C2PA_AI_SOURCE_REGEX = /trainedalgorithmicmedia/i

  C2PA_BLOB_LIMIT = 4.megabytes

  # C2PA manifests live in containers libvips never exposes: a caBX chunk in
  # PNG, APP11/JUMBF segments in JPEG. Read them straight off the file.
  def self.raw_c2pa_blob(file_path, file_ext)
    case file_ext
    when "png" then png_c2pa_blob(file_path)
    when "jpg", "jpeg" then jpeg_c2pa_blob(file_path)
    else ""
    end
  rescue StandardError
    ""
  end

  def self.png_c2pa_blob(file_path)
    File.open(file_path, "rb") do |file|
      return "" unless file.read(8) == "\x89PNG\r\n\x1a\n".b
      blob = +""
      while (header = file.read(8)) && header.bytesize == 8
        length, type = header.unpack("Na4")
        break if %w[IEND IDAT].include?(type)
        if type == "caBX" && blob.bytesize + length <= C2PA_BLOB_LIMIT
          blob << file.read(length).to_s
          file.seek(4, IO::SEEK_CUR) # CRC
        else
          file.seek(length + 4, IO::SEEK_CUR)
        end
      end
      blob
    end
  end

  def self.jpeg_c2pa_blob(file_path)
    File.open(file_path, "rb") do |file|
      return "" unless file.read(2) == "\xFF\xD8".b
      blob = +""
      while (marker = file.read(2)) && marker.bytesize == 2
        break unless marker.getbyte(0) == 0xFF
        code = marker.getbyte(1)
        break if [0xDA, 0xD9].include?(code) # SOS / EOI
        length = file.read(2).to_s.unpack1("n").to_i - 2
        break if length < 0
        if code == 0xEB && blob.bytesize + length <= C2PA_BLOB_LIMIT # APP11
          data = file.read(length).to_s
          blob << data if data.start_with?("JP")
        else
          file.seek(length, IO::SEEK_CUR)
        end
      end
      blob
    end
  end

  # Checks if the file at the specified path is AI-generated.
  # Uses metadata analysis to determine likelihood of AI generation.
  # Returns a hash with :score (0..100) and :reason (string).
  def is_ai_generated?(file_path)
    file_ext = File.extname(file_path).downcase.delete_prefix(".")
    return { score: 0, reason: "not an image" } unless %w[png jpg jpeg gif].include?(file_ext)
    return { score: 0, reason: "file not found" } unless File.exist?(file_path)

    # Cache file type checks
    is_png = file_ext == "png"
    is_jpeg = %w[jpg jpeg].include?(file_ext)

    image = Vips::Image.new_from_file(file_path)
    fetch = ->(key) do
      value = image.get(key)
      value.encode("ASCII", invalid: :replace, undef: :replace).gsub("\u0000", "")
    rescue Vips::Error
      ""
    end

    fields = begin
      image.get_fields
    rescue StandardError
      []
    end

    # === Aggregate metadata === #
    exif_data = fetch.call("exif-data")
    exif_software = fetch.call("exif-ifd0-Software")
    exif_image_desc = fetch.call("exif-ifd0-ImageDescription")
    exif_user_comment = fetch.call("exif-ifd2-UserComment")
    xmp_data = fetch.call("xmp-data").downcase

    png_text_blob = is_png ? fields.grep(/^png-comment-/).map { |k| fetch.call(k) }.join("\n") : ""
    jpeg_comment = is_jpeg ? [fetch.call("jpeg-comment"), fetch.call("jpeg-com")].compact_blank.join("\n") : ""

    c2pa_text = AiMethods.raw_c2pa_blob(file_path, file_ext)
                         .encode("ASCII", invalid: :replace, undef: :replace, replace: " ")
                         .downcase

    combined_text = [
      png_text_blob, exif_data, exif_software, exif_image_desc,
      exif_user_comment, xmp_data, jpeg_comment, c2pa_text,
    ].join("\n").downcase

    # === Calculate score based on various heuristics === #
    score = 0
    reasons = []

    # C2PA
    if xmp_data.match?(C2PA_TOKENS_REGEX) || c2pa_text.match?(C2PA_TOKENS_REGEX)
      score += 80
      reasons << "c2pa manifest present"
    end

    # Manifest explicitly declares an AI digitalSourceType
    if c2pa_text.match?(C2PA_AI_SOURCE_REGEX)
      score += 60
      reasons << "c2pa declares ai source"
    end

    # Known generators
    if (match = combined_text.match(AI_GENERATORS_REGEX))
      score += 70
      reasons << "ai generator: #{match[0]}"
    end

    # SD pipeline tokens
    if combined_text.match?(SD_TOKENS_REGEX)
      score += 60
      reasons << "ai parameter tokens found"
    end

    # Additional fast path for PNG text fields (covers older code paths)
    if is_png &&
       (png_text_blob.match?(/(^|[^a-z])parameters\s*:/i) || png_text_blob.match?(/\bDream\b/i))
      score += 20
      reasons << "png text markers"
    end

    # Heuristic: camera EXIF present and no AI markers -> reduce score
    if is_jpeg &&
       !combined_text.match?(AI_GENERATORS_REGEX) &&
       !combined_text.match?(SD_TOKENS_REGEX) &&
       CAMERA_TOKENS.any? { |t| exif_data.include?(t) }
      score -= 30
      reasons << "camera exif present"
    end

    score = score.clamp(0, 100)
    if score <= 0
      { score: 0, reason: "no ai signals" }
    else
      { score: score, reason: reasons.uniq.join("; ") }
    end
  end
end
