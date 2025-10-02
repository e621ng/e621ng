# frozen_string_literal: true

module AiMethods
  # Known generator and platform markers
  AI_GENERATORS = [
    "NovelAI", "NAI", "Stable Diffusion", "SDXL", "Automatic1111", "A1111",
    "ComfyUI", "InvokeAI", "Midjourney", "DALL·E", "DALL-E", "OpenAI",
    "Bing Image Creator", "Firefly", "Adobe Generative Fill", "Adobe Firefly",
    "Leonardo", "Playground",
  ].freeze

  # Parameter/telltale tokens commonly embedded in PNG/JPEG comments or EXIF
  SD_TOKENS = [
    "Negative prompt:", "Steps:", "Sampler:", "CFG scale:", "Model hash",
    "Hires fix", "Denoising strength", "Clip skip", "Refiner:",
    '"sampler":', '"seed":', '"model":', '"workflow":', "sd-metadata",
    "comfy", "parameters:", "seed:", "sampler:", "cfg:", "hires:",
  ].freeze

  # C2PA / Content Credentials indicators (usually in XMP/JUMBF)
  C2PA_TOKENS = ["c2pa.org", "JUMBF", "manifestStore", "c2pa"].freeze

  # Checks if the file at the specified path is AI-generated.
  # Uses metadata analysis to determine likelihood of AI generation.
  # Returns a hash with :score (0..100) and :reason (string).
  def is_ai_generated?(file_path)
    file_ext = File.extname(file_path).downcase.delete_prefix(".")
    return { score: 0, reason: "not an image" } unless %w[png jpg jpeg gif].include?(file_ext)

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
    xmp_data = fetch.call("xmp-data")

    png_text_blob = file_ext == "png" ? fields.grep(/^png-comment-/).map { |k| fetch.call(k) }.join("\n") : ""
    jpeg_comment = %w[jpg jpeg].include?(file_ext) ? [fetch.call("jpeg-comment"), fetch.call("jpeg-com")].compact_blank.join("\n") : ""

    combined_text = [
      png_text_blob, exif_data, exif_software, exif_image_desc,
      exif_user_comment, xmp_data, jpeg_comment,
    ].join("\n").downcase

    # === Calculate score based on various heuristics === #
    score = 0
    reasons = []

    # C2PA
    if xmp_data.downcase.then { |x| C2PA_TOKENS.any? { |t| x.include?(t.downcase) } }
      score += 80
      reasons << "c2pa manifest present"
    end

    # Known generators
    matched_generators = AI_GENERATORS.select { |m| combined_text.include?(m.downcase) }
    unless matched_generators.empty?
      score += 70
      reasons << "ai generator: #{matched_generators.uniq.first}"
    end

    # SD pipeline tokens
    if SD_TOKENS.any? { |t| combined_text.include?(t.downcase) }
      score += 60
      reasons << "ai parameter tokens found"
    end

    # Additional fast path for PNG text fields (covers older code paths)
    if file_ext == "png" &&
       (png_text_blob.match?(/(^|[^a-z])parameters\s*:/i) || png_text_blob.match?(/\bDream\b/i))
      score += 20
      reasons << "png text markers"
    end

    # Heuristic: camera EXIF present and no AI markers -> reduce score
    camera_tokens = %w[Make Model DateTimeOriginal ExposureTime FNumber ISO]
    if %w[jpg jpeg].include?(file_ext) &&
       matched_generators.empty? &&
       (SD_TOKENS.none? { |t| combined_text.include?(t.downcase) }) &&
       camera_tokens.any? { |t| exif_data.include?(t) }
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
